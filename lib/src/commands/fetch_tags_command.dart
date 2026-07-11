import '../core/git_command.dart';
import '../core/process_runner.dart';
import '../models/git/git_tag.dart';
import '../vcs/parsers/rw_git_parser.dart';

class FetchTagsCommand extends GitCommand<List<GitTag>> {
  FetchTagsCommand(super.runner);

  @override
  Future<List<GitTag>> run(
    String directory, {
    List<String> extraArgs = const [],
    bool streamOutput = false,
  }) async {
    final result = await runner.run(
      'git',
      ['tag', '-l'],
      workingDirectory: directory,
      streamOutput: streamOutput,
    );
    evaluateProcessResult(result);
    return RwGitParser.parseTags(result.stdout?.toString() ?? '');
  }
}
