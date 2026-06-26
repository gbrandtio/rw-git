import '../core/git_command.dart';
import '../core/process_runner.dart';

class BlameCommand extends GitCommand<String> {
  BlameCommand(super.runner);

  @override
  Future<String> run(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) async {
    final result = await runner.run('git', ['blame', ...extraArgs],
        workingDirectory: directory, streamOutput: streamOutput);
    evaluateProcessResult(result);
    return result.stdout?.toString() ?? '';
  }
}
