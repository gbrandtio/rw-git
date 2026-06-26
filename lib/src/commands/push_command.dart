import '../core/git_command.dart';
import '../core/process_runner.dart';

class PushCommand extends GitCommand<bool> {
  PushCommand(super.runner);

  @override
  Future<bool> run(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) async {
    final result = await runner.run('git', ['push', ...extraArgs],
        workingDirectory: directory, streamOutput: streamOutput);
    evaluateProcessResult(result);
    return result.exitCode == 0;
  }
}
