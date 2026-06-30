import 'dart:isolate';
import '../core/git_command.dart';
import '../core/process_runner.dart';
import '../models/git/git_blame.dart';
import '../vcs/parsers/rw_git_parser.dart';

class BlameCommand extends GitCommand<GitBlame> {
  BlameCommand(super.runner);

  @override
  Future<GitBlame> run(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) async {
    final result = await runner.run('git', ['blame', ...extraArgs],
        workingDirectory: directory, streamOutput: streamOutput);
    evaluateProcessResult(result);
    final stdout = result.stdout?.toString() ?? '';
    if (stdout.length > 10000) {
      return await Isolate.run(() => RwGitParser.parseBlame(stdout));
    }
    return RwGitParser.parseBlame(stdout);
  }
}
