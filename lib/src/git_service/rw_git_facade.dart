import 'dart:io';

import '../../rw_git.dart';

import '../commands/init_command.dart';
import '../commands/clone_command.dart';
import '../commands/checkout_command.dart';
import '../commands/fetch_tags_command.dart';
import '../commands/get_commits_command.dart';
import '../commands/stats_command.dart';
import '../commands/shortlog_command.dart';
import '../commands/is_git_repository_command.dart';
import 'parsers/git_url_parser.dart';

/// ----------------------------------------------------------------------------
/// rw_git_facade.dart
/// ----------------------------------------------------------------------------
/// Offers a useful interface for executing various GIT commands and fetching a
/// pretty GIT result. This class acts as a Facade towards the outside world
/// and offers some common operations out-of-the-box (e.g., clone and checkout
/// a specific branch).
class RwGit {
  final String invalidGitCommandResult = "INVALID";
  final String gitRepoIndicator = ".git";

  final ProcessRunner runner;

  RwGit({ProcessRunner? runner})
      : runner = runner ?? ProcessRunner.defaultRunner();

  Future<bool> init(String directoryToInit) {
    return InitCommand(runner).execute(directoryToInit);
  }

  Future<bool> isGitRepository(String directoryToCheck) {
    return IsGitRepositoryCommand(runner).execute(directoryToCheck);
  }

  Future<bool> clone(String localDirectoryToCloneInto, String repository) {
    return CloneCommand(runner, repository: repository)
        .execute(localDirectoryToCloneInto);
  }

  Future<bool> checkout(
      String localCheckoutDirectory, String branchToCheckout) {
    return CheckoutCommand(runner, branchToCheckout: branchToCheckout)
        .execute(localCheckoutDirectory);
  }

  Future<List<String>> fetchTags(String localCheckoutDirectory) {
    return FetchTagsCommand(runner).execute(localCheckoutDirectory);
  }

  Future<List<String>> getCommitsBetween(
      String localCheckoutDirectory, String firstTag, String secondTag) {
    return GetCommitsCommand(runner, firstTag: firstTag, secondTag: secondTag)
        .execute(localCheckoutDirectory);
  }

  Future<ShortStatDto> stats(
      String localCheckoutDirectory, String oldTag, String newTag) {
    return StatsCommand(runner, oldTag: oldTag, newTag: newTag)
        .execute(localCheckoutDirectory);
  }

  Future<List<ShortLogDto>> contributionsByAuthor(
      String localCheckoutDirectory) {
    return ShortlogCommand(runner).execute(localCheckoutDirectory);
  }

  /// Clones the provided [repository] and checks out the provided [branchToCheckout].
  Future<bool> cloneSpecificBranch(String localDirectoryToCloneInto,
      String repository, String branchToCheckout) async {
    bool clonedSuccessfully =
        await clone(localDirectoryToCloneInto, repository);

    if (clonedSuccessfully) {
      String localCheckoutDirectory = localDirectoryToCloneInto +
          Platform.pathSeparator +
          GitUrlParser.parseRepositoryNameFromRepositoryUrl(repository);

      return checkout(localCheckoutDirectory, branchToCheckout);
    }
    return false;
  }

  /// Clones the specified [repository] into the [localDirectoryToCloneInto]
  /// and returns the statistics between the supplied [oldTag] and [newTag]
  Future<ShortStatDto> cloneAndGetStatistics(String localDirectoryToCloneInto,
      String repository, String oldTag, String newTag) async {
    bool clonedSuccessfully =
        await clone(localDirectoryToCloneInto, repository);

    if (clonedSuccessfully) {
      String localCheckoutDirectory = localDirectoryToCloneInto +
          Platform.pathSeparator +
          GitUrlParser.parseRepositoryNameFromRepositoryUrl(repository);

      return stats(localCheckoutDirectory, oldTag, newTag);
    }
    return ShortStatDto.defaultStats();
  }

  /// Generic command execution to support all available git commands.
  Future<String> runCommand(String directory, List<String> args) async {
    final result = await runner.run('git', args, workingDirectory: directory);
    evaluateProcessResult(result);
    return result.stdout?.toString() ?? '';
  }
}
