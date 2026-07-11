import 'dart:isolate';
import '../core/git_command.dart';
import '../core/process_runner.dart';
import '../models/git/git_diff.dart';
import '../vcs/parsers/rw_git_parser.dart';

class DiffCommand extends GitCommand<GitDiff> {
  DiffCommand(super.runner);

  @override
  Future<GitDiff> run(
    String directory, {
    List<String> extraArgs = const [],
    bool streamOutput = false,
  }) async {
    final result = await runner.run(
      'git',
      ['diff', ...extraArgs],
      workingDirectory: directory,
      streamOutput: streamOutput,
    );
    evaluateProcessResult(result);
    final stdout = result.stdout?.toString() ?? '';
    if (stdout.length > 10000) {
      return await Isolate.run(() => RwGitParser.parseDiff(stdout));
    }
    return RwGitParser.parseDiff(stdout);
  }
}
