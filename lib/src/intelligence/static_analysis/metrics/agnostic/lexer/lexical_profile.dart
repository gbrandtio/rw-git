/// A start/end pair of delimiters for a masked block region.
///
/// Used for multi-line comments (`/* ... */`, `=begin ... =end`) and for
/// asymmetric string literals (Lua's `[[ ... ]]`). The lexer masks both
/// identically, so they share one representation.
class BlockDelimiter {
  final String start;
  final String end;

  const BlockDelimiter(this.start, this.end);
}

/// A symmetric string delimiter (the same sequence opens and closes the
/// literal), with optional backslash-escape support.
class StringDelimiter {
  final String delimiter;

  /// Whether `\` escapes the next character inside the literal. Raw strings
  /// (e.g. Go backtick strings) set this to false.
  final bool allowsEscapes;

  const StringDelimiter(this.delimiter, {this.allowsEscapes = true});
}

/// Defines the lexical masking rules of a language: which character
/// sequences open comments and string literals.
///
/// The [FsmLexer] consults this profile instead of hardcoded C-family
/// characters, so `#` can be a comment in Python but a token in C or Dart,
/// and `--[[ ... ]]` can be masked in Lua.
///
/// Ordering contract: within each list, longer delimiters must precede
/// shorter ones that share a prefix (`"""` before `"`, `--[[` before `--`),
/// because the lexer takes the first match. Block delimiters are checked
/// before line comments for the same reason.
class LexicalProfile {
  /// Prefixes that mask the rest of the line (e.g. `//`, `#`, `--`).
  final List<String> lineComments;

  /// Start/end pairs masked as a block, checked before [lineComments].
  final List<BlockDelimiter> blockDelimiters;

  /// Symmetric string delimiters, checked after comments.
  final List<StringDelimiter> stringDelimiters;

  const LexicalProfile({
    required this.lineComments,
    required this.blockDelimiters,
    required this.stringDelimiters,
  });

  /// The historical permissive default: C-family comments plus `#` and
  /// HTML comments. Used for unknown file types where guessing broadly
  /// beats guessing wrong narrowly.
  static const cFamily = LexicalProfile(
    lineComments: ['//', '#'],
    blockDelimiters: [
      BlockDelimiter('/*', '*/'),
      BlockDelimiter('<!--', '-->'),
    ],
    stringDelimiters: [
      StringDelimiter('"'),
      StringDelimiter("'"),
      StringDelimiter('`'),
    ],
  );

  /// Strict C-family: `#` is not a comment, so C/C++ preprocessor
  /// directives and Dart/C# symbols tokenize as code.
  static const cLike = LexicalProfile(
    lineComments: ['//'],
    blockDelimiters: [BlockDelimiter('/*', '*/')],
    stringDelimiters: [StringDelimiter('"'), StringDelimiter("'")],
  );

  static const dart = LexicalProfile(
    lineComments: ['//'],
    blockDelimiters: [BlockDelimiter('/*', '*/')],
    stringDelimiters: [
      StringDelimiter('"""'),
      StringDelimiter("'''"),
      StringDelimiter('"'),
      StringDelimiter("'"),
    ],
  );

  static const python = LexicalProfile(
    lineComments: ['#'],
    blockDelimiters: [],
    stringDelimiters: [
      StringDelimiter('"""'),
      StringDelimiter("'''"),
      StringDelimiter('"'),
      StringDelimiter("'"),
    ],
  );

  static const javascript = LexicalProfile(
    lineComments: ['//'],
    blockDelimiters: [BlockDelimiter('/*', '*/')],
    stringDelimiters: [
      StringDelimiter('`'),
      StringDelimiter('"'),
      StringDelimiter("'"),
    ],
  );

  static const go = LexicalProfile(
    lineComments: ['//'],
    blockDelimiters: [BlockDelimiter('/*', '*/')],
    stringDelimiters: [
      StringDelimiter('`', allowsEscapes: false),
      StringDelimiter('"'),
      StringDelimiter("'"),
    ],
  );

  static const ruby = LexicalProfile(
    lineComments: ['#'],
    blockDelimiters: [BlockDelimiter('=begin', '=end')],
    stringDelimiters: [
      StringDelimiter('"'),
      StringDelimiter("'"),
      StringDelimiter('`'),
    ],
  );

  static const lua = LexicalProfile(
    lineComments: ['--'],
    blockDelimiters: [
      BlockDelimiter('--[[', ']]'),
      // Lua long strings; masked like any other literal.
      BlockDelimiter('[[', ']]'),
    ],
    stringDelimiters: [StringDelimiter('"'), StringDelimiter("'")],
  );

  static const shell = LexicalProfile(
    lineComments: ['#'],
    blockDelimiters: [],
    stringDelimiters: [
      StringDelimiter('"'),
      StringDelimiter("'", allowsEscapes: false),
    ],
  );

  static const xml = LexicalProfile(
    lineComments: [],
    blockDelimiters: [BlockDelimiter('<!--', '-->')],
    stringDelimiters: [StringDelimiter('"'), StringDelimiter("'")],
  );
}
