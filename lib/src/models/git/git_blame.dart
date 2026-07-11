import 'git_blame_line.dart';

/// ----------------------------------------------------------------------------
/// git_blame.dart
/// ----------------------------------------------------------------------------
/// Represents the complete output of a git blame command for a file.
class GitBlame {
  final List<GitBlameLine> lines;

  const GitBlame({this.lines = const []});

  Map<String, dynamic> toJson() => {
    'lines': lines.map((e) => e.toJson()).toList(),
  };
}
