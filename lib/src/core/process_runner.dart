import 'dart:async';
import 'dart:io';
import 'dart:convert';
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
      {String? workingDirectory, bool streamOutput = false});

  /// Executes the given [executable] and streams stdout line-by-line.
  /// Standard error is buffered and an exception is thrown if the process fails.
  Stream<String> runStream(String executable, List<String> arguments,
      {String? workingDirectory});
}

class StandardProcessRunner implements ProcessRunner {
  @override
  Future<ProcessResult> run(String executable, List<String> arguments,
      {String? workingDirectory, bool streamOutput = false}) async {
    try {
      // SECURITY.md: Never use runInShell: true for executing commands.
      final process = await Process.start(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        runInShell: false,
      );

      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();

      final stdoutFuture = process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .forEach((data) {
        stdoutBuffer.write(data);
        if (streamOutput) {
          stdout.write(data);
        }
      });

      final stderrFuture = process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .forEach((data) {
        stderrBuffer.write(data);
        if (streamOutput) {
          stderr.write(data);
        }
      });

      final exitCode = await process.exitCode;
      await Future.wait([stdoutFuture, stderrFuture]);

      return ProcessResult(process.pid, exitCode, stdoutBuffer.toString(),
          stderrBuffer.toString());
    } on ProcessException catch (e) {
      throw GitExecutableNotFoundException(
        message:
            'Failed to execute $executable. Ensure it is installed and in the system PATH.',
        originalException: e,
      );
    }
  }

  @override
  Stream<String> runStream(String executable, List<String> arguments,
      {String? workingDirectory}) async* {
    try {
      // SECURITY.md: Never use runInShell: true for executing commands.
      final process = await Process.start(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        runInShell: false,
      );

      final stderrBuffer = StringBuffer();
      final stderrCompleter = Completer<void>();
      process.stderr.transform(const Utf8Decoder(allowMalformed: true)).listen(
          stderrBuffer.write,
          onDone: stderrCompleter.complete,
          onError: stderrCompleter.completeError);

      yield* process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter());

      await stderrCompleter.future;
      final exitCode = await process.exitCode;

      if (exitCode != 0) {
        evaluateProcessResult(
            ProcessResult(process.pid, exitCode, '', stderrBuffer.toString()));
      }
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
      {String? workingDirectory, bool streamOutput = false}) async {
    final key = '$executable ${arguments.join(' ')}';

    final result = _mockResults[key] ??
        ProcessResult(0, 1, '', 'Mock result not found for $key');

    if (streamOutput) {
      stdout.write(result.stdout);
      stderr.write(result.stderr);
    }

    return result;
  }

  @override
  Stream<String> runStream(String executable, List<String> arguments,
      {String? workingDirectory}) async* {
    final key = '$executable ${arguments.join(' ')}';
    final result = _mockResults[key];

    if (result == null) {
      evaluateProcessResult(
          ProcessResult(0, 1, '', 'Mock result not found for $key'));
    } else {
      if (result.stdout != null) {
        final lines = result.stdout.toString().split('\n');
        for (final line in lines) {
          yield line;
        }
      }
      if (result.exitCode != 0) {
        evaluateProcessResult(result);
      }
    }
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
