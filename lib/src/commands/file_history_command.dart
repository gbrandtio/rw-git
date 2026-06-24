import '../core/git_command.dart';
import '../core/process_runner.dart';
import '../git_service/parsers/rw_git_parser.dart';

class FileHistoryCommand extends GitCommand<List<String>> {
  final String filePath;

  FileHistoryCommand(super.runner, {required this.filePath});

  @override
  Future<List<String>> execute(String directory) async {
    // --follow traces history across renames
    // --oneline is usually easiest to parse for basic history
    final result = await runner.run('git', ['log', '--follow', '--oneline', '--', filePath], workingDirectory: directory);
    evaluateProcessResult(result);
    return RwGitParser.parseGitStdoutBasedOnNewLine(result.stdout?.toString() ?? '');
  }
}
