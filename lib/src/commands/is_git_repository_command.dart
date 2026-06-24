import '../core/git_command.dart';

class IsGitRepositoryCommand extends GitCommand<bool> {
  IsGitRepositoryCommand(super.runner);

  @override
  Future<bool> execute(String directory) async {
    final result = await runner.run('git', ['rev-parse', '--is-inside-work-tree'], workingDirectory: directory);
    // don't evaluateProcessResult because if it's not a git repo, it will exit non-zero and we just return false
    return result.exitCode == 0 && result.stdout.toString().toLowerCase().trim() == "true";
  }
}
