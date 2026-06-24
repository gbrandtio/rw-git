import 'process_runner.dart';

/// ----------------------------------------------------------------------------
/// git_command.dart
/// ----------------------------------------------------------------------------
/// Defines the strategy interface for all Git commands adhering to the
/// Open/Closed Principle.

abstract class GitCommand<T> {
  final ProcessRunner runner;

  GitCommand(this.runner);

  /// Executes the git command within the given [directory]
  Future<T> execute(String directory, {bool streamOutput = false});
}
