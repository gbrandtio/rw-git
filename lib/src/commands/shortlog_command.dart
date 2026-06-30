import '../core/git_command.dart';
import '../core/process_runner.dart';
import '../models/short_log_dto.dart';
import '../vcs/parsers/rw_git_parser.dart';

class ShortlogCommand extends GitCommand<List<ShortLogDto>> {
  ShortlogCommand(super.runner);

  @override
  Future<List<ShortLogDto>> run(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) async {
    final result = await runner.run('git', ['shortlog', 'HEAD', '-s'],
        workingDirectory: directory, streamOutput: streamOutput);
    evaluateProcessResult(result);

    List<String> rawList = RwGitParser.parseGitStdoutBasedOnNewLine(
        result.stdout?.toString() ?? '');
    return rawList.map((e) => RwGitParser.parseGitShortLogStdout(e)).toList();
  }
}
