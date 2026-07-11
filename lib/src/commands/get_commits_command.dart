import 'dart:isolate';
import '../core/git_command.dart';
import '../core/process_runner.dart';
import '../models/git/git_commit.dart';
import '../vcs/parsers/rw_git_parser.dart';

class GetCommitsCommand extends GitCommand<List<GitCommit>> {
  final String firstTag;
  final String secondTag;

  GetCommitsCommand(
    super.runner, {
    required this.firstTag,
    required this.secondTag,
  });

  @override
  Future<List<GitCommit>> run(
    String directory, {
    List<String> extraArgs = const [],
    bool streamOutput = false,
  }) async {
    final result = await runner.run(
      'git',
      ['log', '--pretty=format:%H|%an|%ae|%aI|%s', '$firstTag...$secondTag'],
      workingDirectory: directory,
      streamOutput: streamOutput,
    );
    evaluateProcessResult(result);
    final stdout = result.stdout?.toString() ?? '';
    if (stdout.length > 10000) {
      return await Isolate.run(() => RwGitParser.parseCommits(stdout));
    }
    return RwGitParser.parseCommits(stdout);
  }
}
