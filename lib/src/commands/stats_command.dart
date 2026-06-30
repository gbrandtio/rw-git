import '../core/git_command.dart';
import '../core/process_runner.dart';
import '../models/short_stat_dto.dart';
import '../vcs/parsers/rw_git_parser.dart';

class StatsCommand extends GitCommand<ShortStatDto> {
  final String oldTag;
  final String newTag;

  StatsCommand(super.runner, {required this.oldTag, required this.newTag});

  @override
  Future<ShortStatDto> run(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) async {
    final result = await runner.run(
        'git', ['diff', '--shortstat', oldTag, newTag],
        workingDirectory: directory, streamOutput: streamOutput);
    evaluateProcessResult(result);
    return RwGitParser.parseGitShortStatStdout(result.stdout?.toString() ?? '');
  }
}
