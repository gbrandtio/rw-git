import 'token.dart';

/// A Finite-State Machine (FSM) based lexer that implements zero-allocation
/// source traversal.
///
/// It strictly implements lexical masking by skipping over:
/// - Single-line comments (`//`, `#`)
/// - Multi-line comments (`/* ... */`, `<!-- ... -->`)
/// - String and character literals (`"..."`, `'...'`, `` `...` ``)
///
/// The lexer emits a sequence of [Token] objects representing the
/// semantically meaningful parts of the code.
class FsmLexer {
  final String _source;
  final int _length;
  int _position = 0;

  FsmLexer(this._source) : _length = _source.length;

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
    final char = _source[_position];

    // Newline
    if (char == '\n') {
      _position++;
      return _createToken(TokenType.newline, start, _position);
    }

    // Identifier or Keyword
    if (_isAlpha(char) || char == '_' || char == r'$') {
      while (_position < _length && _isAlphaNumeric(_source[_position])) {
        _position++;
      }
      return _createToken(TokenType.identifier, start, _position);
    }

    // Number literal
    if (_isDigit(char)) {
      while (_position < _length &&
          (_isDigit(_source[_position]) || _source[_position] == '.')) {
        _position++;
      }
      return _createToken(TokenType.number, start, _position);
    }

    // Punctuation
    if (_isPunctuation(char)) {
      _position++;
      return _createToken(TokenType.punctuation, start, _position);
    }

    // Operator (groups contiguous operator characters to form composite operators like === or ->)
    if (_isOperatorChar(char)) {
      while (_position < _length && _isOperatorChar(_source[_position])) {
        _position++;
      }
      return _createToken(TokenType.operator, start, _position);
    }

    // Unknown character fallback
    _position++;
    return _createToken(TokenType.unknown, start, _position);
  }

  void _skipWhitespaceAndMaskedRegions() {
    while (_position < _length) {
      final char = _source[_position];

      if (char == ' ' || char == '\t' || char == '\r') {
        _position++;
        continue;
      }

      // Check for comments
      if (_position + 1 < _length) {
        final nextChar = _source[_position + 1];

        // Single-line comment (//)
        if (char == '/' && nextChar == '/') {
          _skipUntilNewline();
          continue;
        }

        // Single-line comment (#)
        if (char == '#') {
          _skipUntilNewline();
          continue;
        }

        // Multi-line comment (/* ... */)
        if (char == '/' && nextChar == '*') {
          _position += 2;
          _skipUntilSequence('*/');
          continue;
        }

        // XML/HTML multi-line comment (<!-- ... -->)
        if (char == '<' && nextChar == '!') {
          if (_position + 3 < _length &&
              _source.substring(_position, _position + 4) == '<!--') {
            _position += 4;
            _skipUntilSequence('-->');
            continue;
          }
        }
      } else {
        // Handle '#' at the very end of file
        if (char == '#') {
          _skipUntilNewline();
          continue;
        }
      }

      // String literals
      if (char == '"' || char == "'" || char == '`') {
        _skipStringLiteral(char);
        continue;
      }

      // If we reach here, it's not whitespace or a masked region
      break;
    }
  }

  void _skipUntilNewline() {
    while (_position < _length && _source[_position] != '\n') {
      _position++;
    }
  }

  void _skipUntilSequence(String sequence) {
    while (_position < _length) {
      if (_position + sequence.length <= _length &&
          _source.substring(_position, _position + sequence.length) ==
              sequence) {
        _position += sequence.length;
        return;
      }
      _position++;
    }
  }

  void _skipStringLiteral(String quote) {
    _position++; // Skip the opening quote
    while (_position < _length) {
      final char = _source[_position];
      if (char == '\\') {
        // Escape sequence, skip next character
        _position += 2;
      } else if (char == quote) {
        _position++; // Skip the closing quote
        return;
      } else {
        _position++;
      }
    }
  }

  Token _createToken(TokenType type, int start, int end) {
    return Token(type: type, start: start, end: end, source: _source);
  }

  bool _isAlpha(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }

  bool _isDigit(String char) {
    final code = char.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }

  bool _isAlphaNumeric(String char) {
    return _isAlpha(char) || _isDigit(char) || char == '_' || char == r'$';
  }

  bool _isPunctuation(String char) {
    const punctuation = '(){}[];,.';
    return punctuation.contains(char);
  }

  bool _isOperatorChar(String char) {
    const operators = '=+-*/<>!&|^%~?:';
    return operators.contains(char);
  }
}
