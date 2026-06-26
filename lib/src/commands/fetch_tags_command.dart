import '../core/git_command.dart';
import '../core/process_runner.dart';
import '../git_service/parsers/rw_git_parser.dart';

class FetchTagsCommand extends GitCommand<List<String>> {
  FetchTagsCommand(super.runner);

  @override
  Future<List<String>> run(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) async {
    final result = await runner.run('git', ['tag', '-l'],
        workingDirectory: directory, streamOutput: streamOutput);
    evaluateProcessResult(result);
    return RwGitParser.parseGitStdoutBasedOnNewLine(result.stdout.toString());
  }
}
