import 'dart:isolate';
import '../core/git_command.dart';
import '../core/process_runner.dart';
import '../models/git/git_status.dart';
import '../git_service/parsers/rw_git_parser.dart';

class StatusCommand extends GitCommand<GitStatus> {
  StatusCommand(super.runner);

  @override
  Future<GitStatus> run(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) async {
    final result = await runner.run(
        'git', ['status', '--porcelain', ...extraArgs],
        workingDirectory: directory, streamOutput: streamOutput);
    evaluateProcessResult(result);
    final stdout = result.stdout?.toString() ?? '';

    if (stdout.length > 10000) {
      return await Isolate.run(() => RwGitParser.parseStatus(stdout));
    }
    return RwGitParser.parseStatus(stdout);
  }
}
