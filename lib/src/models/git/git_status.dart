import 'git_file_change.dart';

/// ----------------------------------------------------------------------------
/// git_status.dart
/// ----------------------------------------------------------------------------
/// Represents the result of a git status command.
class GitStatus {
  final List<GitFileChange> stagedChanges;
  final List<GitFileChange> unstagedChanges;
  final List<String> untrackedFiles;

  const GitStatus({
    this.stagedChanges = const [],
    this.unstagedChanges = const [],
    this.untrackedFiles = const [],
  });

  Map<String, dynamic> toJson() => {
    'stagedChanges': stagedChanges.map((e) => e.toJson()).toList(),
    'unstagedChanges': unstagedChanges.map((e) => e.toJson()).toList(),
    'untrackedFiles': untrackedFiles,
  };
}
