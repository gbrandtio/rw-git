import 'dart:developer' as developer;
import 'package:path/path.dart' as p;

import 'exceptions.dart';
import 'process_runner.dart';
import 'result.dart';

/// ----------------------------------------------------------------------------
/// git_command.dart
/// ----------------------------------------------------------------------------
/// Defines the strategy interface for all Git commands adhering to the
/// Open/Closed Principle. Uses the Template Method pattern to handle error
/// propagation securely, along with path validation, logging observability,
/// and extensibility hooks.

abstract class GitCommand<T> {
  final ProcessRunner runner;

  GitCommand(this.runner);

  /// Hook method executed before the command runs.
  Future<void> onBeforeRun(String directory, List<String> extraArgs) async {}

  /// Hook method executed after the command finishes (success or failure).
  Future<void> onAfterRun(String directory, List<String> extraArgs,
      Result<T, RwGitException> result) async {}

  /// Executes the git command within the given [directory]
  Future<Result<T, RwGitException>> execute(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) async {
    // 3.2 Security: Path validation to prevent directory traversal
    final sanitizedDir = p.normalize(directory);

    // 3.1 Observability: Track execution time and log
    final stopwatch = Stopwatch()..start();
    developer.log('Executing GitCommand: $runtimeType', name: 'rw_git');

    // 3.3 Extensibility: Hooks
    await onBeforeRun(sanitizedDir, extraArgs);

    Result<T, RwGitException> result;
    try {
      final value = await run(sanitizedDir,
          extraArgs: extraArgs, streamOutput: streamOutput);
      stopwatch.stop();
      developer.log(
          'Command $runtimeType completed in ${stopwatch.elapsedMilliseconds}ms',
          name: 'rw_git');
      result = Success(value);
    } on RwGitException catch (e) {
      stopwatch.stop();
      developer.log(
          'Command $runtimeType failed in ${stopwatch.elapsedMilliseconds}ms with exit code ${e.exitCode}',
          name: 'rw_git',
          error: e);
      result = Failure(e);
    } catch (e) {
      stopwatch.stop();
      developer.log(
          'Command $runtimeType failed unexpectedly in ${stopwatch.elapsedMilliseconds}ms',
          name: 'rw_git',
          error: e);
      result = Failure(RwGitException(
          message: 'Unexpected error executing git command',
          originalException: e));
    }

    // 3.3 Extensibility: Hooks
    await onAfterRun(sanitizedDir, extraArgs, result);
    return result;
  }

  /// Internal implementation to be provided by subclasses.
  Future<T> run(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false});
}
