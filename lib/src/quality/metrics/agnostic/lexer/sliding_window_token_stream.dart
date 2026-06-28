import 'token.dart';

/// Provides a sliding window over a list of tokens, allowing algorithms
/// to look ahead and combine composite tokens without backtracking.
class SlidingWindowTokenStream {
  final List<Token> _tokens;
  int _position = 0;

  SlidingWindowTokenStream(this._tokens);

  bool get hasNext => _position < _tokens.length;

  Token get current => _tokens[_position];

  /// Looks ahead [offset] tokens without consuming them.
  Token? peek([int offset = 1]) {
    if (_position + offset < _tokens.length) {
      return _tokens[_position + offset];
    }
    return null;
  }

  /// Consumes and returns the next token.
  Token next() {
    if (!hasNext) {
      throw StateError('No more tokens');
    }
    return _tokens[_position++];
  }

  /// Attempts to match a sequence of token lexemes. If they match, advances the
  /// window and returns true. Otherwise, does not advance and returns false.
  bool matchSequence(List<String> lexemes) {
    if (_position + lexemes.length > _tokens.length) {
      return false;
    }

    for (int i = 0; i < lexemes.length; i++) {
      if (_tokens[_position + i].lexeme != lexemes[i]) {
        return false;
      }
    }

    _position += lexemes.length;
    return true;
  }
}
