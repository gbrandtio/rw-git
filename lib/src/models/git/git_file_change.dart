// ----------------------------------------------------------------------------
// git_file_change.dart
// ----------------------------------------------------------------------------

/// Represents the status of a file change in Git.
enum GitFileStatus {
  added,
  modified,
  deleted,
  renamed,
  copied,
  untracked,
  unknown
}

/// Represents a file change in a Git status output.
class GitFileChange {
  final String path;
  final GitFileStatus status;

  const GitFileChange({
    required this.path,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'status': status.name,
      };
}
