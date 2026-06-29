/// ----------------------------------------------------------------------------
/// git_file_diff.dart
/// ----------------------------------------------------------------------------
/// Represents the diff of a single file.
class GitFileDiff {
  final String path;
  final int additions;
  final int deletions;
  final String contentDiff;

  const GitFileDiff({
    required this.path,
    required this.additions,
    required this.deletions,
    required this.contentDiff,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'additions': additions,
        'deletions': deletions,
        'contentDiff': contentDiff,
      };
}
