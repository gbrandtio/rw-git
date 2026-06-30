import '../core/git_command.dart';
import '../core/process_runner.dart';
import '../models/git/git_branch.dart';
import '../vcs/parsers/rw_git_parser.dart';

class BranchCommand extends GitCommand<List<GitBranch>> {
  BranchCommand(super.runner);

  @override
  Future<List<GitBranch>> run(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) async {
    final result = await runner.run('git', ['branch', ...extraArgs],
        workingDirectory: directory, streamOutput: streamOutput);
    evaluateProcessResult(result);
    return RwGitParser.parseBranches(result.stdout?.toString() ?? '');
  }
}
