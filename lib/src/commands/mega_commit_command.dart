import '../core/git_command.dart';
import '../core/process_runner.dart';
import '../git_service/parsers/rw_git_parser.dart';

class MegaCommitCheckCommand extends GitCommand<List<String>> {
  final int thresholdLinesChanged;

  MegaCommitCheckCommand(super.runner, {this.thresholdLinesChanged = 500});

  @override
  Future<List<String>> execute(String directory) async {
    // git log --shortstat returns the stat per commit which we can parse to find mega-commits
    final result = await runner.run('git', ['log', '--shortstat', '--format=oneline'], workingDirectory: directory);
    evaluateProcessResult(result);
    
    // the parser logic will be handled outside, but for now we just return the raw lines to be processed
    return RwGitParser.parseGitStdoutBasedOnNewLine(result.stdout?.toString() ?? '');
  }
}
