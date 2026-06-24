import 'dart:io';
import 'exceptions.dart';

/// ----------------------------------------------------------------------------
/// process_runner.dart
/// ----------------------------------------------------------------------------
/// Interface for running OS processes securely, facilitating dependency inversion
/// for easier testing (MockProcessRunner).

abstract class ProcessRunner {
  /// Default runner utilizing dart:io Process.run
  factory ProcessRunner.defaultRunner() => StandardProcessRunner();

  /// Mock runner for testing
  factory ProcessRunner.mock() => MockProcessRunner();

  /// Executes the given [executable] with the provided [arguments] securely.
  Future<ProcessResult> run(String executable, List<String> arguments,
      {String? workingDirectory});
}

class StandardProcessRunner implements ProcessRunner {
  @override
  Future<ProcessResult> run(String executable, List<String> arguments,
      {String? workingDirectory}) async {
    try {
      // SECURITY.md: Never use runInShell: true for executing commands.
      final result = await Process.run(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        runInShell: false,
      );

      return result;
    } on ProcessException catch (e) {
      throw GitExecutableNotFoundException(
        message:
            'Failed to execute $executable. Ensure it is installed and in the system PATH.',
        originalException: e,
      );
    }
  }
}

class MockProcessRunner implements ProcessRunner {
  final Map<String, ProcessResult> _mockResults = {};

  MockProcessRunner();

  void setMockResult(String executable, List<String> arguments, int exitCode,
      String stdout, String stderr) {
    final key = '$executable ${arguments.join(' ')}';
    _mockResults[key] = ProcessResult(0, exitCode, stdout, stderr);
  }

  @override
  Future<ProcessResult> run(String executable, List<String> arguments,
      {String? workingDirectory}) async {
    final key = '$executable ${arguments.join(' ')}';
    return _mockResults[key] ??
        ProcessResult(0, 1, '', 'Mock result not found for $key');
  }
}

/// Helper method to parse ProcessResult and throw specific errors.
void evaluateProcessResult(ProcessResult result) {
  if (result.exitCode != 0) {
    final errOutput = result.stderr?.toString().toLowerCase() ?? '';

    if (errOutput.contains('did not match any file(s) known to git')) {
      // Extract branch name roughly if possible or just use generic
      throw GitBranchNotFoundException('Unknown',
          exitCode: result.exitCode, stderr: errOutput);
    } else if (errOutput.contains('not a git repository')) {
      throw GitNotInitializedException('Unknown',
          exitCode: result.exitCode, stderr: errOutput);
    } else if (errOutput.contains('conflict')) {
      throw GitMergeConflictException(
          exitCode: result.exitCode, stderr: errOutput);
    }

    throw RwGitException(
      message: 'Git command failed',
      exitCode: result.exitCode,
      stderr: errOutput,
    );
  }
}
