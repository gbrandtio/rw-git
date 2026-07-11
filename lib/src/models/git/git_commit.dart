/// ----------------------------------------------------------------------------
/// git_commit.dart
/// ----------------------------------------------------------------------------
/// Represents a Git commit with its basic metadata.
class GitCommit {
  final String hash;
  final String authorName;
  final String authorEmail;
  final String date;
  final String message;

  const GitCommit({
    required this.hash,
    required this.authorName,
    required this.authorEmail,
    required this.date,
    required this.message,
  });

  Map<String, dynamic> toJson() => {
        'hash': hash,
        'authorName': authorName,
        'authorEmail': authorEmail,
        'date': date,
        'message': message,
      };
}
