import '../lexer/token.dart';

/// Distinguishes a conditional expression's `?` from a nullable-type
/// marker (`int? x`): a ternary has a matching `:` at the same bracket
/// level before the expression ends.
bool isTernaryOperator(List<Token> tokens, int from) {
  var delta = 0;
  for (var j = from + 1; j < tokens.length; j++) {
    final token = tokens[j];
    if (token.type == TokenType.punctuation) {
      switch (token.lexeme) {
        case '(':
        case '[':
        case '{':
          delta++;
        case ')':
        case ']':
        case '}':
          if (delta == 0) return false; // Expression closed without a `:`.
          delta--;
        case ';':
        case ',':
          if (delta == 0) return false;
      }
    } else if (token.type == TokenType.operator &&
        token.lexeme == ':' &&
        delta == 0) {
      return true;
    }
  }
  return false;
}

/// A control keyword glued to `#` is a preprocessor directive (`#if`).
bool isPreprocessorKeyword(Token? prev, Token current) =>
    prev != null &&
    prev.type == TokenType.unknown &&
    prev.lexeme == '#' &&
    prev.end == current.start;
