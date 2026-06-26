import '../core/git_command.dart';
import '../core/process_runner.dart';
import '../git_service/parsers/rw_git_parser.dart';

class GetCommitsCommand extends GitCommand<List<String>> {
  final String firstTag;
  final String secondTag;

  GetCommitsCommand(super.runner,
      {required this.firstTag, required this.secondTag});

  @override
  Future<List<String>> run(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) async {
    // using ... syntax for rev-list
    final result = await runner.run(
        'git', ['rev-list', '$firstTag...$secondTag'],
        workingDirectory: directory, streamOutput: streamOutput);
    evaluateProcessResult(result);
    return RwGitParser.parseGitStdoutBasedOnNewLine(
        result.stdout?.toString() ?? '');
  }
}
