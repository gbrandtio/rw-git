import '../core/git_command.dart';
import '../core/process_runner.dart';

class StatusCommand extends GitCommand<String> {
  StatusCommand(super.runner);

  @override
  Future<String> run(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) async {
    final result = await runner.run('git', ['status', '--short', ...extraArgs],
        workingDirectory: directory, streamOutput: streamOutput);
    evaluateProcessResult(result);
    return result.stdout?.toString() ?? '';
  }
}
