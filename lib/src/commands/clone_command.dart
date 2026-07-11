import 'dart:io';
import '../core/git_command.dart';
import '../core/process_runner.dart';

class CloneCommand extends GitCommand<bool> {
  final String repository;

  CloneCommand(super.runner, {required this.repository});

  @override
  Future<bool> run(
    String directory, {
    List<String> extraArgs = const [],
    bool streamOutput = false,
  }) async {
    await Directory(directory).create(recursive: true);

    // Using -- to prevent flag injection, though clone usually takes the repo directly
    final result = await runner.run(
      'git',
      ['clone', '--', repository],
      workingDirectory: directory,
      streamOutput: streamOutput,
    );
    evaluateProcessResult(result);
    return result.exitCode == 0;
  }
}
