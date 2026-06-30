/// Represents a token type in the agnostic lexical analyzer.
enum TokenType {
  identifier,
  number,
  operator,
  punctuation,
  whitespace, // Often ignored, but kept for structural anchors
  newline, // Important for line-based complexity or indentation
  unknown,
  eof,
}

/// Represents a single token extracted from the source code.
///
/// Uses zero-allocation techniques by storing the start and end indices
/// of the token within the original source string, rather than copying
/// the substring itself.
class Token {
  final TokenType type;
  final int start;
  final int end;

  /// A reference to the original source string to avoid allocation.
  final String _source;

  const Token({
    required this.type,
    required this.start,
    required this.end,
    required String source,
  }) : _source = source;

  /// Lazily extracts the lexeme string when needed.
  String get lexeme => _source.substring(start, end);

  @override
  String toString() => 'Token($type, "$lexeme")';
}
