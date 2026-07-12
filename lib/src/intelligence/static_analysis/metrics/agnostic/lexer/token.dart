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

  /// For [TokenType.newline] tokens: the indentation width of the *next*
  /// line, with tabs expanded to the next multiple of 8 columns. `-1` when
  /// the next line carries no code (blank, comment-only, or end of file) or
  /// for non-newline tokens. This is the only structural whitespace signal
  /// the lexer preserves; the [NestingResolver] uses it to synthesize
  /// indent/dedent events for indentation-structured languages.
  final int indentWidth;

  /// A reference to the original source string to avoid allocation.
  final String _source;

  const Token({
    required this.type,
    required this.start,
    required this.end,
    required String source,
    this.indentWidth = -1,
  }) : _source = source;

  /// Lazily extracts the lexeme string when needed.
  String get lexeme => _source.substring(start, end);

  @override
  String toString() => 'Token($type, "$lexeme")';
}
