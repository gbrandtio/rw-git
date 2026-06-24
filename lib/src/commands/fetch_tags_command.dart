import '../core/git_command.dart';
import '../core/process_runner.dart';
import '../git_service/parsers/rw_git_parser.dart';

class FetchTagsCommand extends GitCommand<List<String>> {
  FetchTagsCommand(super.runner);

  @override
  Future<List<String>> execute(String directory) async {
    final result =
        await runner.run('git', ['tag', '-l'], workingDirectory: directory);
    evaluateProcessResult(result);
    return RwGitParser.parseGitStdoutBasedOnNewLine(result.stdout.toString());
  }
}
