import '../core/git_command.dart';
import '../core/process_runner.dart';
import '../models/short_stat_dto.dart';
import '../git_service/parsers/rw_git_parser.dart';

class StatsCommand extends GitCommand<ShortStatDto> {
  final String oldTag;
  final String newTag;

  StatsCommand(super.runner, {required this.oldTag, required this.newTag});

  @override
  Future<ShortStatDto> execute(String directory) async {
    final result = await runner.run('git', ['diff', '--shortstat', oldTag, newTag], workingDirectory: directory);
    evaluateProcessResult(result);
    return RwGitParser.parseGitShortStatStdout(result.stdout?.toString() ?? '');
  }
}
