import 'lexical_profile.dart';
import 'token.dart';

/// A Finite-State Machine (FSM) based lexer that implements zero-allocation
/// source traversal: the hot path operates exclusively on code units
/// (integers), never on substring or single-character String objects.
///
/// Lexical masking (comments and string literals) is driven by an injected
/// [LexicalProfile] rather than hardcoded C-family characters, so the same
/// FSM handles Python `#` comments, Lua `--[[ ... ]]` blocks, or Go raw
/// backtick strings without language-specific code paths. Without a profile
/// it defaults to [LexicalProfile.cFamily], the permissive historical
/// behavior.
///
/// The lexer emits a sequence of [Token] objects representing the
/// semantically meaningful parts of the code.
class FsmLexer {
  final String _source;
  final int _length;
  final LexicalProfile _profile;
  int _position = 0;

  FsmLexer(this._source, [LexicalProfile? profile])
    : _length = _source.length,
      _profile = profile ?? LexicalProfile.cFamily;

  static const int _tab = 0x09; // \t
  static const int _lf = 0x0A; // \n
  static const int _cr = 0x0D; // \r
  static const int _space = 0x20;
  static const int _dollar = 0x24; // $
  static const int _plus = 0x2B; // +
  static const int _minus = 0x2D; // -
  static const int _dot = 0x2E; // .
  static const int _digit0 = 0x30; // 0
  static const int _digit9 = 0x39; // 9
  static const int _upperA = 0x41; // A
  static const int _upperB = 0x42; // B
  static const int _upperE = 0x45; // E
  static const int _upperO = 0x4F; // O
  static const int _upperX = 0x58; // X
  static const int _upperZ = 0x5A; // Z
  static const int _backslash = 0x5C; // \
  static const int _underscore = 0x5F; // _
  static const int _lowerA = 0x61; // a
  static const int _lowerB = 0x62; // b
  static const int _lowerE = 0x65; // e
  static const int _lowerO = 0x6F; // o
  static const int _lowerX = 0x78; // x
  static const int _lowerZ = 0x7A; // z

  // Membership bitmasks for ASCII punctuation/operator classification,
  // precomputed so the hot loop does two integer ops instead of a
  // String.contains scan. Covers '(){}[];,.' and '=+-*/<>!&|^%~?:'.
  static final List<bool> _punctuationTable = _buildTable('(){}[];,.');
  static final List<bool> _operatorTable = _buildTable('=+-*/<>!&|^%~?:');

  static List<bool> _buildTable(String chars) {
    final table = List<bool>.filled(128, false);
    for (var i = 0; i < chars.length; i++) {
      table[chars.codeUnitAt(i)] = true;
    }
    return table;
  }

  /// Tokenizes the entire source string.
  List<Token> tokenize() {
    final tokens = <Token>[];
    Token? token;
    while ((token = _nextToken()) != null) {
      if (token!.type != TokenType.eof) {
        tokens.add(token);
      }
    }
    return tokens;
  }

  /// Extracts the next token from the stream.
  Token? _nextToken() {
    if (_position >= _length) {
      return null;
    }

    _skipWhitespaceAndMaskedRegions();

    if (_position >= _length) {
      return null;
    }

    final start = _position;
    final code = _source.codeUnitAt(_position);

    // Newline, stamped with the indentation width of the line it opens so
    // structural analysis of indentation languages stays possible downstream.
    if (code == _lf) {
      _position++;
      return Token(
        type: TokenType.newline,
        start: start,
        end: _position,
        source: _source,
        indentWidth: _measureIndent(_position),
      );
    }

    // Identifier or Keyword
    if (_isAlpha(code) || code == _underscore || code == _dollar) {
      while (_position < _length &&
          _isAlphaNumeric(_source.codeUnitAt(_position))) {
        _position++;
      }
      return _createToken(TokenType.identifier, start, _position);
    }

    // Number literal
    if (_isDigit(code)) {
      _scanNumber(code);
      return _createToken(TokenType.number, start, _position);
    }

    // Punctuation
    if (code < 128 && _punctuationTable[code]) {
      _position++;
      return _createToken(TokenType.punctuation, start, _position);
    }

    // Operator (groups contiguous operator characters to form composite operators like === or ->)
    if (code < 128 && _operatorTable[code]) {
      while (_position < _length) {
        final next = _source.codeUnitAt(_position);
        if (next >= 128 || !_operatorTable[next]) break;
        _position++;
      }
      return _createToken(TokenType.operator, start, _position);
    }

    // Unknown character fallback
    _position++;
    return _createToken(TokenType.unknown, start, _position);
  }

  /// Consumes a number literal starting at the current position.
  ///
  /// Handles radix prefixes (`0x1A`, `0b101`, `0o17`), digit separators
  /// (`1_000_000`), decimals (`123.456`) and scientific notation
  /// (`1e5`, `1.5e-3`). A trailing dot is not consumed, so `1.toString()`
  /// lexes as number `1` followed by punctuation and an identifier.
  void _scanNumber(int firstCode) {
    // Radix prefix: consume the prefix, then any alphanumeric tail.
    if (firstCode == _digit0 && _position + 1 < _length) {
      final next = _source.codeUnitAt(_position + 1);
      if (next == _lowerX ||
          next == _upperX ||
          next == _lowerB ||
          next == _upperB ||
          next == _lowerO ||
          next == _upperO) {
        _position += 2;
        while (_position < _length &&
            _isAlphaNumeric(_source.codeUnitAt(_position))) {
          _position++;
        }
        return;
      }
    }

    while (_position < _length) {
      final code = _source.codeUnitAt(_position);

      if (_isDigit(code) || code == _underscore) {
        _position++;
        continue;
      }

      // Decimal point, only when followed by a digit.
      if (code == _dot &&
          _position + 1 < _length &&
          _isDigit(_source.codeUnitAt(_position + 1))) {
        _position++;
        continue;
      }

      // Exponent, only when followed by [+-]?digit.
      if (code == _lowerE || code == _upperE) {
        var lookahead = _position + 1;
        if (lookahead < _length) {
          final sign = _source.codeUnitAt(lookahead);
          if (sign == _plus || sign == _minus) {
            lookahead++;
          }
        }
        if (lookahead < _length && _isDigit(_source.codeUnitAt(lookahead))) {
          _position = lookahead + 1;
          continue;
        }
      }

      break;
    }
  }

  /// Measures the indentation width of the line starting at [pos], expanding
  /// tabs to the next multiple of 8 columns (Python's rule). Returns -1 when
  /// the line carries no code: blank, line-comment-only, or end of input.
  /// Pure lookahead; does not consume.
  int _measureIndent(int pos) {
    var width = 0;
    var p = pos;
    while (p < _length) {
      final c = _source.codeUnitAt(p);
      if (c == _space) {
        width++;
      } else if (c == _tab) {
        width += 8 - (width % 8);
      } else if (c == _cr) {
        // Width contribution of \r is nil; \r\n blank lines resolve below.
      } else {
        break;
      }
      p++;
    }
    if (p >= _length || _source.codeUnitAt(p) == _lf) {
      return -1; // Blank line or end of input.
    }
    for (final prefix in _profile.lineComments) {
      if (_matchesAt(p, prefix)) {
        return -1; // Comment-only line.
      }
    }
    return width;
  }

  void _skipWhitespaceAndMaskedRegions() {
    outer:
    while (_position < _length) {
      final code = _source.codeUnitAt(_position);

      if (code == _space || code == _tab || code == _cr) {
        _position++;
        continue;
      }

      // Block regions first so that e.g. Lua's `--[[` wins over `--`.
      for (final block in _profile.blockDelimiters) {
        if (_matchesAt(_position, block.start)) {
          _position += block.start.length;
          _skipUntilSequence(block.end);
          continue outer;
        }
      }

      for (final prefix in _profile.lineComments) {
        if (_matchesAt(_position, prefix)) {
          _skipUntilNewline();
          continue outer;
        }
      }

      for (final string in _profile.stringDelimiters) {
        if (_matchesAt(_position, string.delimiter)) {
          _skipStringLiteral(string);
          continue outer;
        }
      }

      // If we reach here, it's not whitespace or a masked region
      break;
    }
  }

  /// Compares [pattern] against the source at [pos] code unit by code unit,
  /// without allocating a substring.
  bool _matchesAt(int pos, String pattern) {
    final patternLength = pattern.length;
    if (pos + patternLength > _length) {
      return false;
    }
    for (var i = 0; i < patternLength; i++) {
      if (_source.codeUnitAt(pos + i) != pattern.codeUnitAt(i)) {
        return false;
      }
    }
    return true;
  }

  void _skipUntilNewline() {
    while (_position < _length && _source.codeUnitAt(_position) != _lf) {
      _position++;
    }
  }

  void _skipUntilSequence(String sequence) {
    while (_position < _length) {
      if (_matchesAt(_position, sequence)) {
        _position += sequence.length;
        return;
      }
      _position++;
    }
  }

  void _skipStringLiteral(StringDelimiter string) {
    _position += string.delimiter.length; // Skip the opening delimiter
    while (_position < _length) {
      final code = _source.codeUnitAt(_position);
      if (string.allowsEscapes && code == _backslash) {
        // Escape sequence, skip next character
        _position += 2;
      } else if (_matchesAt(_position, string.delimiter)) {
        _position += string.delimiter.length; // Skip the closing delimiter
        return;
      } else {
        _position++;
      }
    }
  }

  Token _createToken(TokenType type, int start, int end) {
    return Token(type: type, start: start, end: end, source: _source);
  }

  bool _isAlpha(int code) {
    return (code >= _upperA && code <= _upperZ) ||
        (code >= _lowerA && code <= _lowerZ);
  }

  bool _isDigit(int code) {
    return code >= _digit0 && code <= _digit9;
  }

  bool _isAlphaNumeric(int code) {
    return _isAlpha(code) ||
        _isDigit(code) ||
        code == _underscore ||
        code == _dollar;
  }
}
