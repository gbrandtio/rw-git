/// ----------------------------------------------------------------------------
/// git_blame_line.dart
/// ----------------------------------------------------------------------------
/// Represents a single line in a git blame output.
class GitBlameLine {
  final String commitHash;
  final String author;
  final DateTime date;
  final int lineNumber;
  final String content;

  const GitBlameLine({
    required this.commitHash,
    required this.author,
    required this.date,
    required this.lineNumber,
    required this.content,
  });

  Map<String, dynamic> toJson() => {
    'commitHash': commitHash,
    'author': author,
    'date': date.toIso8601String(),
    'lineNumber': lineNumber,
    'content': content,
  };
}
