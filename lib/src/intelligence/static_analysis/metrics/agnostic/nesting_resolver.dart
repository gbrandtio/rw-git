import 'language_profile.dart';
import 'lexer/token.dart';

/// The classification of an open block frame.
///
/// Only [control] and [lambda] frames contribute to cognitive nesting depth,
/// mirroring the SonarSource cognitive-complexity specification: control
/// structures and nested functions/lambdas nest; function bodies, class
/// bodies, and literal braces do not.
enum FrameKind { control, lambda, neutral }

/// The result of a nesting pass: a per-token control-flow nesting depth,
/// plus aggregate frame statistics for depth-distribution metrics.
class NestingResolution {
  /// Cognitive nesting depth at each token index (parallel to the token
  /// list). A control-flow keyword's own increment should use the depth at
  /// its index, which is the depth *outside* the block it opens.
  final List<int> depths;

  /// Deepest cognitive nesting reached anywhere in the stream.
  final int maxDepth;

  /// Number of nesting frames (control + lambda) opened.
  final int frameCount;

  /// Sum over all nesting frames of the depth at which each opened.
  final int frameDepthSum;

  const NestingResolution({
    required this.depths,
    required this.maxDepth,
    required this.frameCount,
    required this.frameDepthSum,
  });

  double get averageFrameDepth =>
      frameCount > 0 ? frameDepthSum / frameCount : 0.0;
}

/// Computes control-flow nesting depth from a token stream in a single pass,
/// using the strategy declared by the profile's [BlockStructure].
///
/// This is the sole source of nesting truth for the agnostic metrics:
/// algorithms consume the resolved depths instead of re-deriving them from
/// raw bracket counting.
class NestingResolver {
  final LanguageProfile profile;

  NestingResolver(this.profile);

  NestingResolution resolve(List<Token> tokens) {
    switch (profile.blockStructure) {
      case BlockStructure.braces:
        return _resolveBraces(tokens);
      case BlockStructure.indentation:
        return _resolveIndentation(tokens);
      case BlockStructure.keywordEnd:
        return _resolveKeywordEnd(tokens);
    }
  }

  /// Keywords whose block bodies count as cognitive nesting. `case`/`when`
  /// arms live inside the frame their `switch` already opened, so they are
  /// excluded from frame creation.
  bool _opensControlBlock(String lexeme) =>
      profile.controlFlowKeywords.contains(lexeme) &&
      lexeme != 'case' &&
      lexeme != 'when';

  /// Brace languages: a `{` opens a control frame when it terminates a
  /// pending control-flow clause, a lambda frame when it follows a lambda
  /// introducer or a `)` inside an argument list, and a neutral frame
  /// otherwise (function/class bodies, literals). Parentheses and square
  /// brackets are expression grouping, never nesting.
  NestingResolution _resolveBraces(List<Token> tokens) {
    final depths = List<int>.filled(tokens.length, 0);
    final frames = <FrameKind>[];
    var depth = 0;
    var maxDepth = 0;
    var frameCount = 0;
    var frameDepthSum = 0;
    var exprDepth = 0;
    var pendingControl = false;
    var pendingExprDepth = 0;
    Token? prevSignificant;

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      depths[i] = depth;

      if (token.type == TokenType.newline) {
        continue; // Formatting-neutral: pending clauses span newlines.
      }

      if (token.type == TokenType.identifier &&
          _opensControlBlock(token.lexeme) &&
          !_isPreprocessor(prevSignificant, token)) {
        pendingControl = true;
        pendingExprDepth = exprDepth;
      } else if (token.type == TokenType.punctuation) {
        switch (token.lexeme) {
          case '(':
          case '[':
            exprDepth++;
          case ')':
          case ']':
            if (exprDepth > 0) exprDepth--;
          case '{':
            final FrameKind kind;
            if (pendingControl && exprDepth == pendingExprDepth) {
              kind = FrameKind.control;
              pendingControl = false;
            } else if (_isLambdaBrace(prevSignificant, exprDepth)) {
              kind = FrameKind.lambda;
            } else {
              kind = FrameKind.neutral;
            }
            frames.add(kind);
            if (kind != FrameKind.neutral) {
              frameCount++;
              frameDepthSum += depth;
              depth++;
              if (depth > maxDepth) maxDepth = depth;
            }
          case '}':
            if (frames.isNotEmpty && frames.removeLast() != FrameKind.neutral) {
              depth--;
            }
          case ';':
            // Statement end at clause level: the control structure took a
            // brace-less body (`if (a) return;`), so nothing nests.
            if (pendingControl && exprDepth <= pendingExprDepth) {
              pendingControl = false;
            }
        }
      }

      prevSignificant = token;
    }

    return NestingResolution(
      depths: depths,
      maxDepth: maxDepth,
      frameCount: frameCount,
      frameDepthSum: frameDepthSum,
    );
  }

  bool _isLambdaBrace(Token? prev, int exprDepth) {
    if (prev == null) return false;
    if (prev.type == TokenType.operator &&
        profile.lambdaIntroducers.contains(prev.lexeme)) {
      return true;
    }
    // A block following `)` inside an argument list is a function literal
    // passed as an argument (`items.forEach((x) { ... })`).
    return prev.type == TokenType.punctuation &&
        prev.lexeme == ')' &&
        exprDepth > 0;
  }

  /// A control keyword glued to a `#` (C preprocessor `#if`, `#ifdef`) is a
  /// directive, not control flow.
  bool _isPreprocessor(Token? prev, Token current) =>
      prev != null &&
      prev.type == TokenType.unknown &&
      prev.lexeme == '#' &&
      prev.end == current.start;

  /// Indentation languages: synthesize indent/dedent events from the
  /// [Token.indentWidth] stamps on newline tokens, using a width stack —
  /// the classic Python tokenizer algorithm. Lines inside open brackets
  /// (implicit continuation) and blank/comment lines (width -1) never
  /// produce events. A block opened by a control-flow line nests; a block
  /// opened by a structural line (`def`, `class`) does not.
  NestingResolution _resolveIndentation(List<Token> tokens) {
    final depths = List<int>.filled(tokens.length, 0);
    final widths = <int>[0];
    final kinds = <FrameKind>[];
    var depth = 0;
    var maxDepth = 0;
    var frameCount = 0;
    var frameDepthSum = 0;
    var exprDepth = 0;
    var lineKind = FrameKind.neutral;
    var atLineStart = true;

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      depths[i] = depth;

      if (token.type == TokenType.newline) {
        final width = token.indentWidth;
        if (exprDepth == 0 && width >= 0) {
          if (width > widths.last) {
            widths.add(width);
            kinds.add(lineKind);
            if (lineKind == FrameKind.control) {
              frameCount++;
              frameDepthSum += depth;
              depth++;
              if (depth > maxDepth) maxDepth = depth;
            }
          } else {
            // Pop to the nearest enclosing width; tolerate inconsistent
            // dedents by stopping at the first level <= the new width.
            while (widths.length > 1 && widths.last > width) {
              widths.removeLast();
              if (kinds.removeLast() == FrameKind.control) depth--;
            }
          }
        }
        if (exprDepth == 0) {
          atLineStart = true;
        }
        continue;
      }

      if (atLineStart) {
        lineKind =
            token.type == TokenType.identifier &&
                _opensControlBlock(token.lexeme)
            ? FrameKind.control
            : FrameKind.neutral;
        atLineStart = false;
      }

      if (token.type == TokenType.punctuation) {
        switch (token.lexeme) {
          case '(':
          case '[':
          case '{':
            exprDepth++;
          case ')':
          case ']':
          case '}':
            if (exprDepth > 0) exprDepth--;
        }
      }
    }

    return NestingResolution(
      depths: depths,
      maxDepth: maxDepth,
      frameCount: frameCount,
      frameDepthSum: frameDepthSum,
    );
  }

  /// Keyword-terminated languages (Ruby, Lua, shell): control and structural
  /// openers push a frame when they appear in statement position (first
  /// significant token of a line — filtering out Ruby/Lua modifier forms
  /// like `x = 1 if y`); lambda openers (Ruby/Lua block `do`) push anywhere
  /// unless the line already opened a frame (`while x do` is one block, not
  /// two). Closers pop unconditionally.
  NestingResolution _resolveKeywordEnd(List<Token> tokens) {
    final depths = List<int>.filled(tokens.length, 0);
    final frames = <FrameKind>[];
    var depth = 0;
    var maxDepth = 0;
    var frameCount = 0;
    var frameDepthSum = 0;
    var atLineStart = true;
    var lineOpenedFrame = false;

    void open(FrameKind kind) {
      frames.add(kind);
      lineOpenedFrame = true;
      if (kind != FrameKind.neutral) {
        frameCount++;
        frameDepthSum += depth;
        depth++;
        if (depth > maxDepth) maxDepth = depth;
      }
    }

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      depths[i] = depth;

      if (token.type == TokenType.newline) {
        atLineStart = true;
        lineOpenedFrame = false;
        continue;
      }

      if (token.type == TokenType.identifier) {
        final lexeme = token.lexeme;
        if (profile.blockClosers.contains(lexeme)) {
          if (frames.isNotEmpty && frames.removeLast() != FrameKind.neutral) {
            depth--;
          }
        } else if (atLineStart && profile.blockOpeners.contains(lexeme)) {
          open(FrameKind.control);
        } else if (atLineStart &&
            profile.structuralBlockOpeners.contains(lexeme)) {
          open(FrameKind.neutral);
        } else if (!lineOpenedFrame &&
            profile.lambdaBlockOpeners.contains(lexeme)) {
          open(FrameKind.lambda);
        }
      }

      atLineStart = false;
    }

    return NestingResolution(
      depths: depths,
      maxDepth: maxDepth,
      frameCount: frameCount,
      frameDepthSum: frameDepthSum,
    );
  }
}
