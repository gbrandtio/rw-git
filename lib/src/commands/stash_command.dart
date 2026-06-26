import '../core/git_command.dart';
import '../core/process_runner.dart';

class StashCommand extends GitCommand<bool> {
  StashCommand(super.runner);

  @override
  Future<bool> run(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) async {
    final result = await runner.run('git', ['stash', ...extraArgs],
        workingDirectory: directory, streamOutput: streamOutput);
    evaluateProcessResult(result);
    return result.exitCode == 0;
  }
}
