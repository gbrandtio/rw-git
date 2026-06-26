import '../core/git_command.dart';
import '../core/process_runner.dart';

class DiffCommand extends GitCommand<String> {
  DiffCommand(super.runner);

  @override
  Future<String> run(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) async {
    final result = await runner.run('git', ['diff', ...extraArgs],
        workingDirectory: directory, streamOutput: streamOutput);
    evaluateProcessResult(result);
    return result.stdout?.toString() ?? '';
  }
}
