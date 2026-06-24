import '../core/git_command.dart';
import '../core/process_runner.dart';
import '../models/short_log_dto.dart';
import '../git_service/parsers/rw_git_parser.dart';

class ShortlogCommand extends GitCommand<List<ShortLogDto>> {
  ShortlogCommand(super.runner);

  @override
  Future<List<ShortLogDto>> execute(String directory) async {
    final result = await runner.run('git', ['shortlog', 'HEAD', '-s'],
        workingDirectory: directory);
    evaluateProcessResult(result);

    List<String> rawList = RwGitParser.parseGitStdoutBasedOnNewLine(
        result.stdout?.toString() ?? '');
    return rawList.map((e) => RwGitParser.parseGitShortLogStdout(e)).toList();
  }
}
