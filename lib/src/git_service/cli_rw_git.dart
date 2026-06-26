import '../../rw_git.dart';
import '../commands/init_command.dart';
import '../commands/clone_command.dart';
import '../commands/checkout_command.dart';
import '../commands/fetch_tags_command.dart';
import '../commands/get_commits_command.dart';
import '../commands/stats_command.dart';
import '../commands/shortlog_command.dart';
import '../commands/is_git_repository_command.dart';
import 'base_rw_git.dart';

/// The existing CLI implementation using [ProcessRunner] and OS git.
class CliRwGit extends BaseRwGit {
  final ProcessRunner runner;

  CliRwGit({ProcessRunner? runner})
      : runner = runner ?? ProcessRunner.defaultRunner();

  @override
  Future<bool> init(String directoryToInit, {bool streamOutput = false}) {
    return InitCommand(runner)
        .execute(directoryToInit, streamOutput: streamOutput);
  }

  @override
  Future<bool> isGitRepository(String directoryToCheck,
      {bool streamOutput = false}) {
    return IsGitRepositoryCommand(runner)
        .execute(directoryToCheck, streamOutput: streamOutput);
  }

  @override
  Future<bool> clone(String localDirectoryToCloneInto, String repository,
      {bool streamOutput = false}) {
    return CloneCommand(runner, repository: repository)
        .execute(localDirectoryToCloneInto, streamOutput: streamOutput);
  }

  @override
  Future<bool> checkout(String localCheckoutDirectory, String branchToCheckout,
      {bool streamOutput = false}) {
    return CheckoutCommand(runner, branchToCheckout: branchToCheckout)
        .execute(localCheckoutDirectory, streamOutput: streamOutput);
  }

  @override
  Future<List<String>> fetchTags(String localCheckoutDirectory,
      {bool streamOutput = false}) {
    return FetchTagsCommand(runner)
        .execute(localCheckoutDirectory, streamOutput: streamOutput);
  }

  @override
  Future<List<String>> getCommitsBetween(
      String localCheckoutDirectory, String firstTag, String secondTag,
      {bool streamOutput = false}) {
    return GetCommitsCommand(runner, firstTag: firstTag, secondTag: secondTag)
        .execute(localCheckoutDirectory, streamOutput: streamOutput);
  }

  @override
  Future<ShortStatDto> stats(
      String localCheckoutDirectory, String oldTag, String newTag,
      {bool streamOutput = false}) {
    return StatsCommand(runner, oldTag: oldTag, newTag: newTag)
        .execute(localCheckoutDirectory, streamOutput: streamOutput);
  }

  @override
  Future<List<ShortLogDto>> contributionsByAuthor(String localCheckoutDirectory,
      {bool streamOutput = false}) {
    return ShortlogCommand(runner)
        .execute(localCheckoutDirectory, streamOutput: streamOutput);
  }

  @override
  Future<String> runCommand(String directory, List<String> args,
      {bool streamOutput = false}) async {
    final result = await runner.run('git', args,
        workingDirectory: directory, streamOutput: streamOutput);
    evaluateProcessResult(result);
    return result.stdout?.toString() ?? '';
  }
}
