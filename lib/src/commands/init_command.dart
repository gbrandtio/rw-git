import 'dart:io';
import '../core/git_command.dart';

class InitCommand extends GitCommand<bool> {
  InitCommand(super.runner);

  @override
  Future<bool> execute(String directory) async {
    await Directory(directory).create(recursive: true);
    final result = await runner.run('git', ['init'], workingDirectory: directory);
    return result.exitCode == 0;
  }
}
