import '../core/git_command.dart';
import '../core/process_runner.dart';
import '../vcs/parsers/rw_git_parser.dart';

class MegaCommitCheckCommand extends GitCommand<List<String>> {
  final int thresholdLinesChanged;

  MegaCommitCheckCommand(super.runner, {this.thresholdLinesChanged = 500});

  @override
  Future<List<String>> run(
    String directory, {
    List<String> extraArgs = const [],
    bool streamOutput = false,
  }) async {
    // git log --shortstat returns the stat per commit which we can parse to find mega-commits
    final result = await runner.run(
      'git',
      ['log', '--shortstat', '--format=oneline'],
      workingDirectory: directory,
      streamOutput: streamOutput,
    );
    evaluateProcessResult(result);

    // Return the raw lines to be parsed externally.
    return RwGitParser.parseGitStdoutBasedOnNewLine(
      result.stdout?.toString() ?? '',
    );
  }
}
