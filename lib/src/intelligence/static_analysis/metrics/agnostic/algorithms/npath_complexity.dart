import 'agnostic_metric_algorithm.dart';
import 'token_scan.dart';
import '../lexer/token.dart';
import '../language_profile.dart';
import '../nesting_resolver.dart';

/// Computes NPath Complexity (Nejmeh, 1988) with jump-terminator
/// awareness (ADR-0019).
///
/// NPath counts acyclic execution paths through a *function*: sequential
/// statements multiply their path counts, an `if` contributes
/// `NP(then) + NP(else)` (with an implicit else of 1), a loop contributes
/// `NP(body) + 1`, a switch contributes the sum of its arms, and each
/// boolean operator in a condition adds one path.
///
/// **Guard-clause divergence from PMD/Nejmeh:** when a branch body ends
/// in a jump terminator (`return`, `throw`, `break`, `continue`, or
/// `raise`), its paths are folded *additively* into a separate
/// `terminatedPaths` accumulator instead of multiplying with downstream
/// statements. This models the reality that terminated branches exit the
/// function (or loop) and never combine with downstream logic.  The
/// standard Nejmeh/PMD computation multiplies guard clauses as if both
/// outcomes flow through the entire remaining function — a documented
/// criticism of NPath that penalises well-structured code.  With this
/// correction, sequential guard clauses score linearly (N guards + 1
/// continuation) instead of exponentially (2^N).  See ADR-0019.
///
/// The token stream covers a whole file, so the [NestingResolver]'s frame
/// events are used to segment it: every neutral or lambda frame (function
/// body, class body, closure) starts an independent segment whose paths
/// never multiply with its siblings' — except `try`/`finally`-style bodies
/// and switch-arm blocks, which are transparent and fold into their
/// enclosing scope. The reported file value is the *maximum* segment value,
/// i.e. the NPath of the worst function in the file.
///
/// Threshold: NPath > 200 indicates a function that requires more test
/// cases than a team can realistically write.
class NpathComplexityAlgorithm implements AgnosticMetricAlgorithm<int> {
  static const _cap = 1 << 30;

  static const Set<String> _ifLike = {'if', 'unless'};
  static const Set<String> _elseIfLike = {'elif', 'elsif', 'elseif'};
  static const Set<String> _loopLike = {
    'for',
    'while',
    'until',
    'do',
    'foreach',
    'repeat',
  };
  static const Set<String> _switchLike = {'switch', 'match', 'select'};
  static const Set<String> _catchLike = {'catch', 'except', 'rescue'};

  /// Jump-terminator keywords whose presence at the end of a branch
  /// body triggers additive (instead of multiplicative) path folding.
  /// These are *not* control-flow keywords — they are identifiers
  /// detected at statement level.  See ADR-0019.
  static const Set<String> _jumpTerminators = {
    'return',
    'throw',
    'break',
    'continue',
    'raise', // Python equivalent of throw.
  };

  /// Keywords whose block runs unconditionally: its paths multiply straight
  /// into the enclosing scope instead of forming a branch or a segment.
  static const Set<String> _transparent = {
    'try',
    'finally',
    'ensure',
    'with',
    'begin',
    'defer',
    'go',
  };

  @override
  int calculate(List<Token> tokens, LanguageProfile profile) {
    if (tokens.isEmpty) return 1;
    return _Walker(tokens, profile).run();
  }
}

int _mulCap(int a, int b) {
  final r = a * b; // Operands are capped, so this cannot overflow 63 bits.
  return r >= NpathComplexityAlgorithm._cap ? NpathComplexityAlgorithm._cap : r;
}

int _addCap(int a, int b) {
  final r = a + b;
  return r >= NpathComplexityAlgorithm._cap ? NpathComplexityAlgorithm._cap : r;
}

/// How a closing scope folds its path count into its parent.
enum _FoldKind {
  ifBranch,
  elseIfBranch,
  elseBranch,
  loop,
  switchBlock,
  catchBranch,
  generic,
  segment,
}

class _Scope {
  final _FoldKind kind;

  /// Boolean operators counted in this scope's own condition.
  final int boolOps;

  /// The keyword that introduced the scope (detects do-while tails).
  final String opener;

  /// NPath product of the completed sequential statements.
  int product = 1;

  /// Boolean operators of the statement currently being read.
  int stmtBoolOps = 0;

  /// An if/else-if chain whose branch sums await a possible `else`.
  int chainSum = 0;
  int chainBoolOps = 0;
  bool chainOpen = false;

  /// Arm partitioning: switch cases, and branch keywords that share their
  /// construct's single frame (keyword-end `elsif`/`else`/`when`/`rescue`).
  int armSum = 0;
  bool sawArm = false;
  bool hasDefaultArm = false;

  /// Paths from branches whose bodies ended with a jump terminator
  /// (`return`, `throw`, `break`, `continue`, `raise`).  These paths
  /// are folded additively rather than multiplicatively because they
  /// exit the function (or loop) and never reach downstream code.
  /// See ADR-0019.
  int terminatedPaths = 0;

  /// Whether the most recently completed statement in this scope was
  /// a jump terminator.  Set when a jump-terminator identifier is seen
  /// at statement level; cleared when the next non-jump statement
  /// begins.
  bool endsWithJump = false;

  _Scope(this.kind, this.boolOps, this.opener);

  void flushStatement() {
    if (stmtBoolOps > 0) {
      product = _mulCap(product, stmtBoolOps + 1);
      stmtBoolOps = 0;
    }
  }

  void flushChain() {
    if (chainOpen) {
      // The +1 is the implicit fall-through path of a chain with no `else`.
      product = _mulCap(product, _addCap(chainSum, 1 + chainBoolOps));
      chainOpen = false;
      chainSum = 0;
      chainBoolOps = 0;
    }
  }

  /// Closes the current arm and opens the next. [keepCurrent] keeps the
  /// paths accumulated before the first arm keyword (an if-then body);
  /// otherwise they are discarded (a switch subject expression).
  void startArm({required bool keepCurrent}) {
    flushStatement();
    flushChain();
    if (sawArm || keepCurrent) armSum = _addCap(armSum, product);
    product = 1;
    sawArm = true;
  }
}

class _Walker {
  final List<Token> tokens;
  final LanguageProfile profile;
  final bool _keywordEnd;
  final bool _indentation;

  final List<_Scope> _scopes = [_Scope(_FoldKind.segment, 0, '')];
  final List<int> _segments = [];

  _FoldKind? _pendingKind;
  int _pendingBoolOps = 0;
  int _pendingExprDepth = 0;
  String _pendingOpener = '';
  bool _pendingTransparent = false;
  bool _pendingEndsWithJump = false;

  int _exprDepth = 0;
  int _lastDoCloseIndex = -1;
  int _prevSignificantIndex = -1;

  _Walker(this.tokens, this.profile)
    : _keywordEnd = profile.blockStructure == BlockStructure.keywordEnd,
      _indentation = profile.blockStructure == BlockStructure.indentation;

  _Scope get _scope => _scopes.last;

  int run() {
    final events = NestingResolver(profile).resolve(tokens).events;
    var eventIndex = 0;

    for (var i = 0; i < tokens.length; i++) {
      var consumedByFrame = false;
      while (eventIndex < events.length && events[eventIndex].tokenIndex == i) {
        final event = events[eventIndex++];
        if (event.isOpen) {
          _openFrame(event, i);
          consumedByFrame = true;
        } else {
          _closeFrame(event, i);
        }
      }

      final token = tokens[i];
      if (token.type == TokenType.newline) {
        if (!_keywordEnd && !_indentation) continue;
        if (_exprDepth == 0) {
          // Indentation mode: a control line whose block never opened is a
          // single-line body (`if a: return`).
          if (_pendingKind != null) _resolvePendingAsLeaf();
          _scope.flushStatement();
          _pendingTransparent = false;
        }
        continue;
      }
      if (token.type == TokenType.whitespace || token.type == TokenType.eof) {
        continue;
      }

      _maybeFlushChain(token, consumedByFrame);

      switch (token.type) {
        case TokenType.identifier:
          _handleIdentifier(token, i, consumedByFrame);
        case TokenType.operator:
          _handleOperator(token, i);
        case TokenType.punctuation:
          _handlePunctuation(token);
        default:
          break;
      }

      _prevSignificantIndex = i;
    }

    if (_pendingKind != null) _resolvePendingAsLeaf();
    while (_scopes.length > 1) {
      _popScope(-1);
    }
    _segments.add(_finishScope(_scopes.first).clamp(1, _cap));

    var result = 1;
    for (final value in _segments) {
      if (value > result) result = value;
    }
    return result;
  }

  static const _cap = NpathComplexityAlgorithm._cap;

  void _openFrame(NestingEvent event, int i) {
    if (event.kind == FrameKind.control) {
      _FoldKind kind;
      var boolOps = 0;
      var opener = '';
      if (_keywordEnd) {
        opener = tokens[i].lexeme;
        kind = _classifyKeywordEndOpener(opener);
      } else {
        kind = _pendingKind ?? _FoldKind.generic;
        boolOps = _pendingBoolOps;
        opener = _pendingOpener;
      }
      _scopes.add(_Scope(kind, boolOps, opener));
    } else if (_pendingTransparent && event.kind == FrameKind.neutral) {
      _scopes.add(_Scope(_FoldKind.generic, 0, ''));
    } else {
      // Function/class/closure body: an independent segment whose paths
      // never multiply with the enclosing scope's.
      _scopes.add(_Scope(_FoldKind.segment, 0, ''));
    }
    _pendingKind = null;
    _pendingBoolOps = 0;
    _pendingOpener = '';
    _pendingTransparent = false;
  }

  _FoldKind _classifyKeywordEndOpener(String lexeme) {
    if (NpathComplexityAlgorithm._ifLike.contains(lexeme)) {
      return _FoldKind.ifBranch;
    }
    if (NpathComplexityAlgorithm._loopLike.contains(lexeme)) {
      return _FoldKind.loop;
    }
    if (lexeme == 'case') return _FoldKind.switchBlock;
    return _FoldKind.generic;
  }

  void _closeFrame(NestingEvent event, int i) {
    // A brace-less body pending at the closer (`if (a) x() }`) resolves
    // against the scope that is about to close.
    if (_pendingKind != null) _resolvePendingAsLeaf();
    _popScope(i);
  }

  void _popScope(int tokenIndex) {
    if (_scopes.length <= 1) return;
    final scope = _scopes.removeLast();
    final child = _finishScope(scope);
    if (scope.kind == _FoldKind.segment) {
      _segments.add(child.clamp(1, _cap));
      return;
    }
    _fold(_scope, scope, child);
    if (scope.kind == _FoldKind.loop && scope.opener == 'do') {
      _lastDoCloseIndex = tokenIndex;
    }
  }

  int _finishScope(_Scope scope) {
    scope.flushStatement();
    scope.flushChain();
    final base = scope.sawArm
        ? _addCap(scope.armSum, scope.product)
        : scope.product;
    return _addCap(base, scope.terminatedPaths);
  }

  void _fold(_Scope parent, _Scope scope, int child) {
    // Guard-clause shortcut (ADR-0019): when a branch body ends in a
    // jump terminator, its paths terminate — they never combine with
    // downstream code.  Fold them additively into the parent's
    // terminatedPaths accumulator and let only the implicit fall-
    // through (value 1) multiply into product.
    if (_isJumpTerminatedGuardBranch(scope)) {
      parent.terminatedPaths = _addCap(parent.terminatedPaths, child);
      return;
    }

    switch (scope.kind) {
      case _FoldKind.ifBranch:
        if (_keywordEnd) {
          // Branches shared this frame as arms; add the fall-through path
          // unless a bare `else` arm was present.
          parent.product = _mulCap(
            parent.product,
            _addCap(child, (scope.hasDefaultArm ? 0 : 1) + scope.boolOps),
          );
        } else {
          parent.chainSum = child;
          parent.chainBoolOps = scope.boolOps;
          parent.chainOpen = true;
        }
      case _FoldKind.elseIfBranch:
        if (parent.chainOpen) {
          parent.chainSum = _addCap(parent.chainSum, child);
          parent.chainBoolOps += scope.boolOps;
        } else {
          parent.chainSum = child;
          parent.chainBoolOps = scope.boolOps;
          parent.chainOpen = true;
        }
      case _FoldKind.elseBranch:
        if (parent.chainOpen) {
          parent.chainSum = _addCap(parent.chainSum, child);
          parent.product = _mulCap(
            parent.product,
            _addCap(parent.chainSum, parent.chainBoolOps),
          );
          parent.chainOpen = false;
          parent.chainSum = 0;
          parent.chainBoolOps = 0;
        } else {
          // `for ... else` and friends: the body runs on the same paths.
          parent.product = _mulCap(parent.product, child);
        }
      case _FoldKind.loop:
      case _FoldKind.catchBranch:
        parent.product = _mulCap(
          parent.product,
          _addCap(child, 1 + scope.boolOps),
        );
      case _FoldKind.switchBlock:
        parent.product = _mulCap(
          parent.product,
          _addCap(child, (scope.hasDefaultArm ? 0 : 1) + scope.boolOps),
        );
      case _FoldKind.generic:
      case _FoldKind.segment:
        parent.product = _mulCap(parent.product, child);
    }
  }

  /// A scope qualifies as a jump-terminated guard branch when:
  ///  1. It is an `ifBranch` or `elseIfBranch` (guard clauses are
  ///     always if/else-if constructs).
  ///  2. Its body ended with a jump terminator (`endsWithJump`).
  ///  3. It has no boolean operators in its condition — boolean ops
  ///     add paths that are *not* terminated by the jump, so the
  ///     standard multiplicative folding must apply.  Guard clauses
  ///     with compound conditions (e.g. `if (a && b) return;`) keep
  ///     the standard behaviour.
  bool _isJumpTerminatedGuardBranch(_Scope scope) {
    if (!scope.endsWithJump) return false;
    if (scope.boolOps != 0) return false;
    return scope.kind == _FoldKind.ifBranch ||
        scope.kind == _FoldKind.elseIfBranch;
  }

  /// Folds a pending decision whose body turned out to be a single
  /// statement (`if (a) return;`, `if a: return`) as a leaf of NPath 1.
  /// When the single statement was a jump terminator, the leaf is
  /// marked so that `_fold` can apply additive guard-clause folding.
  void _resolvePendingAsLeaf() {
    final leaf = _Scope(_pendingKind!, _pendingBoolOps, _pendingOpener);
    leaf.endsWithJump = _pendingEndsWithJump;
    _fold(_scope, leaf, 1);
    _pendingKind = null;
    _pendingBoolOps = 0;
    _pendingOpener = '';
    _pendingEndsWithJump = false;
  }

  /// An open chain survives only `else`/`elif` continuations and block
  /// closers (whose close event already ran); anything else at statement
  /// level seals it with the implicit fall-through path.
  void _maybeFlushChain(Token token, bool consumedByFrame) {
    if (!_scope.chainOpen ||
        _pendingKind != null ||
        _exprDepth != 0 ||
        consumedByFrame) {
      return;
    }
    final lexeme = token.lexeme;
    if (token.type == TokenType.identifier &&
        (lexeme == 'else' ||
            NpathComplexityAlgorithm._elseIfLike.contains(lexeme))) {
      return;
    }
    if (token.type == TokenType.punctuation && lexeme == '}') return;
    if (_keywordEnd &&
        token.type == TokenType.identifier &&
        profile.blockClosers.contains(lexeme)) {
      return;
    }
    _scope.flushChain();
  }

  void _handleIdentifier(Token token, int i, bool consumedByFrame) {
    final lexeme = token.lexeme;

    // Detect jump terminators at statement level.  A jump terminator
    // (`return`, `throw`, `break`, `continue`, `raise`) seen at
    // _exprDepth == 0 marks the current scope as ending with a jump.
    if (_exprDepth == 0 &&
        NpathComplexityAlgorithm._jumpTerminators.contains(lexeme)) {
      _scope.endsWithJump = true;
      // Also mark the pending braceless-body tracker so that
      // _resolvePendingAsLeaf can propagate it.
      if (_pendingKind != null) {
        _pendingEndsWithJump = true;
      }
      return;
    }

    // Any non-jump identifier at statement level resets the flag.
    if (_exprDepth == 0) {
      _scope.endsWithJump = false;
      _pendingEndsWithJump = false;
    }

    if (profile.isOperatorKeyword(lexeme) &&
        (lexeme == 'and' || lexeme == 'or')) {
      _countBoolOp();
      return;
    }

    if (_keywordEnd) {
      _handleKeywordEndIdentifier(lexeme, consumedByFrame);
      return;
    }

    if (lexeme == 'default' && _scope.kind == _FoldKind.switchBlock) {
      _scope.hasDefaultArm = true;
      _scope.startArm(keepCurrent: false);
      _pendingTransparent = true;
      return;
    }

    if (NpathComplexityAlgorithm._transparent.contains(lexeme)) {
      _pendingTransparent = true;
      if (!profile.isControlFlow(lexeme)) return;
      // Python-style `try:`/`with:` open control frames; they fold as
      // unconditional pass-through blocks.
      _setPending(_FoldKind.generic, lexeme, i);
      return;
    }

    if (!profile.isControlFlow(lexeme) ||
        isPreprocessorKeyword(_prevSignificant(), token)) {
      return;
    }

    if (NpathComplexityAlgorithm._ifLike.contains(lexeme)) {
      if (_pendingKind == _FoldKind.elseBranch) {
        _pendingKind = _FoldKind.elseIfBranch; // `else if`
      } else {
        _setPending(_FoldKind.ifBranch, lexeme, i);
      }
    } else if (NpathComplexityAlgorithm._elseIfLike.contains(lexeme)) {
      _setPending(_FoldKind.elseIfBranch, lexeme, i);
    } else if (lexeme == 'else') {
      // An inline conditional (`a if b else c`) never opened a frame for
      // its `if`; resolve it before repurposing the pending slot.
      if (_pendingKind == _FoldKind.ifBranch ||
          _pendingKind == _FoldKind.elseIfBranch) {
        _resolvePendingAsLeaf();
      }
      _setPending(_FoldKind.elseBranch, lexeme, i);
    } else if (lexeme == 'case' || lexeme == 'when') {
      if (_scope.kind == _FoldKind.switchBlock) {
        _scope.startArm(keepCurrent: false);
        _pendingTransparent = true;
      }
    } else if (NpathComplexityAlgorithm._loopLike.contains(lexeme)) {
      final isDoWhileTail =
          lexeme == 'while' &&
          _lastDoCloseIndex >= 0 &&
          _prevSignificantIndex == _lastDoCloseIndex;
      if (!isDoWhileTail) _setPending(_FoldKind.loop, lexeme, i);
    } else if (NpathComplexityAlgorithm._switchLike.contains(lexeme)) {
      _setPending(_FoldKind.switchBlock, lexeme, i);
    } else if (NpathComplexityAlgorithm._catchLike.contains(lexeme)) {
      _setPending(_FoldKind.catchBranch, lexeme, i);
    }
  }

  void _handleKeywordEndIdentifier(String lexeme, bool consumedByFrame) {
    if (consumedByFrame || profile.blockClosers.contains(lexeme)) return;

    if (lexeme == 'else') {
      if (_scope.kind == _FoldKind.ifBranch ||
          _scope.kind == _FoldKind.switchBlock) {
        _scope.hasDefaultArm = true;
        _scope.startArm(keepCurrent: _scope.kind == _FoldKind.ifBranch);
      }
    } else if (NpathComplexityAlgorithm._elseIfLike.contains(lexeme)) {
      if (_scope.kind == _FoldKind.ifBranch) {
        _scope.startArm(keepCurrent: true);
      }
    } else if (lexeme == 'when') {
      if (_scope.kind == _FoldKind.switchBlock) {
        _scope.startArm(keepCurrent: false);
      }
    } else if (NpathComplexityAlgorithm._catchLike.contains(lexeme)) {
      // `rescue` partitions its `begin`/`def` body: paths sum.
      _scope.startArm(keepCurrent: true);
    } else if (profile.isControlFlow(lexeme) &&
        (NpathComplexityAlgorithm._ifLike.contains(lexeme) ||
            NpathComplexityAlgorithm._loopLike.contains(lexeme))) {
      // Modifier form (`x = 1 if a`): doubles the statement's paths.
      _scope.stmtBoolOps++;
    }
  }

  void _handleOperator(Token token, int i) {
    final lexeme = token.lexeme;
    if (lexeme == '&&' || lexeme == '||') {
      _countBoolOp();
    } else if (lexeme == '?' && isTernaryOperator(tokens, i)) {
      _countBoolOp();
    }
  }

  void _countBoolOp() {
    if (_pendingKind != null && _pendingKind != _FoldKind.elseBranch) {
      _pendingBoolOps++;
    } else {
      _scope.stmtBoolOps++;
    }
  }

  void _handlePunctuation(Token token) {
    switch (token.lexeme) {
      case '(':
      case '[':
        _exprDepth++;
      case ')':
      case ']':
        if (_exprDepth > 0) _exprDepth--;
      case '{':
        // Braces are frames in brace languages (handled via events) and
        // expression brackets in indentation languages.
        if (_indentation) _exprDepth++;
      case '}':
        if (_indentation && _exprDepth > 0) _exprDepth--;
      case ';':
        if (_pendingKind != null && _exprDepth <= _pendingExprDepth) {
          _resolvePendingAsLeaf();
        } else if (_exprDepth == 0) {
          _scope.flushStatement();
        }
        if (_exprDepth == 0) _pendingTransparent = false;
    }
  }

  void _setPending(_FoldKind kind, String opener, int i) {
    _pendingKind = kind;
    _pendingBoolOps = 0;
    _pendingExprDepth = _exprDepth;
    _pendingOpener = opener;
    _pendingEndsWithJump = false;
  }

  Token? _prevSignificant() =>
      _prevSignificantIndex >= 0 ? tokens[_prevSignificantIndex] : null;
}
