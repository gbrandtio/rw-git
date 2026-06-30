import '../core/git_command.dart';
import '../core/process_runner.dart';
import '../models/git/git_commit.dart';
import '../vcs/parsers/rw_git_parser.dart';

class ShowCommand extends GitCommand<GitCommit> {
  ShowCommand(super.runner);

  @override
  Future<GitCommit> run(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) async {
    final result = await runner.run(
        'git', ['show', '-s', '--format=%H|%an|%ae|%aI|%s', ...extraArgs],
        workingDirectory: directory, streamOutput: streamOutput);
    evaluateProcessResult(result);
    final commits = RwGitParser.parseCommits(result.stdout?.toString() ?? '');
    return commits.isNotEmpty
        ? commits.first
        : const GitCommit(
            hash: '', authorName: '', authorEmail: '', date: '', message: '');
  }
}
