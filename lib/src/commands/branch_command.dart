import '../core/git_command.dart';
import '../core/process_runner.dart';

class BranchCommand extends GitCommand<List<String>> {
  BranchCommand(super.runner);

  @override
  Future<List<String>> run(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) async {
    final result = await runner.run('git', ['branch', ...extraArgs],
        workingDirectory: directory, streamOutput: streamOutput);
    evaluateProcessResult(result);
    return result.stdout
            ?.toString()
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .toList() ??
        [];
  }
}
