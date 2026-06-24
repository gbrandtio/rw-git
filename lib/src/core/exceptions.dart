/// ----------------------------------------------------------------------------
/// exceptions.dart
/// ----------------------------------------------------------------------------
/// Strongly typed exceptions for the rw_git package based on
/// ERROR_HANDLING.md guidelines.

class RwGitException implements Exception {
  final String message;
  final int? exitCode;
  final String? stderr;
  final Object? originalException;

  RwGitException({
    required this.message,
    this.exitCode,
    this.stderr,
    this.originalException,
  });

  @override
  String toString() {
    return 'RwGitException: $message\nExit code: $exitCode\nStderr: $stderr\nOriginal exception: $originalException';
  }
}

class GitBranchNotFoundException extends RwGitException {
  final String branchName;

  GitBranchNotFoundException(this.branchName, {int? exitCode, String? stderr})
      : super(
          message: 'Branch not found: $branchName',
          exitCode: exitCode,
          stderr: stderr,
        );
}

class GitNotInitializedException extends RwGitException {
  final String directory;

  GitNotInitializedException(this.directory, {int? exitCode, String? stderr})
      : super(
          message: 'Directory is not a git repository: $directory',
          exitCode: exitCode,
          stderr: stderr,
        );
}

class GitExecutableNotFoundException extends RwGitException {
  GitExecutableNotFoundException({String? message, Object? originalException})
      : super(
          message: message ??
              'Failed to execute git. Ensure git is installed and in the system PATH.',
          originalException: originalException,
        );
}

class GitMergeConflictException extends RwGitException {
  GitMergeConflictException({int? exitCode, String? stderr})
      : super(
          message: 'Merge conflict detected.',
          exitCode: exitCode,
          stderr: stderr,
        );
}
