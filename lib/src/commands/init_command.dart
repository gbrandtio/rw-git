import 'dart:io';
import '../core/git_command.dart';
import '../core/process_runner.dart';

class InitCommand extends GitCommand<bool> {
  InitCommand(super.runner);

  @override
  Future<bool> run(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) async {
    await Directory(directory).create(recursive: true);
    final result = await runner.run('git', ['init'],
        workingDirectory: directory, streamOutput: streamOutput);
    evaluateProcessResult(result);
    return result.exitCode == 0;
  }
}
