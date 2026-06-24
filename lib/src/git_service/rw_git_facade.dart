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

  Future<bool> init(String directoryToInit, {bool streamOutput = false}) {
    return InitCommand(runner)
        .execute(directoryToInit, streamOutput: streamOutput);
  }

  Future<bool> isGitRepository(String directoryToCheck,
      {bool streamOutput = false}) {
    return IsGitRepositoryCommand(runner)
        .execute(directoryToCheck, streamOutput: streamOutput);
  }

  Future<bool> clone(String localDirectoryToCloneInto, String repository,
      {bool streamOutput = false}) {
    return CloneCommand(runner, repository: repository)
        .execute(localDirectoryToCloneInto, streamOutput: streamOutput);
  }

  Future<bool> checkout(String localCheckoutDirectory, String branchToCheckout,
      {bool streamOutput = false}) {
    return CheckoutCommand(runner, branchToCheckout: branchToCheckout)
        .execute(localCheckoutDirectory, streamOutput: streamOutput);
  }

  Future<List<String>> fetchTags(String localCheckoutDirectory,
      {bool streamOutput = false}) {
    return FetchTagsCommand(runner)
        .execute(localCheckoutDirectory, streamOutput: streamOutput);
  }

  Future<List<String>> getCommitsBetween(
      String localCheckoutDirectory, String firstTag, String secondTag,
      {bool streamOutput = false}) {
    return GetCommitsCommand(runner, firstTag: firstTag, secondTag: secondTag)
        .execute(localCheckoutDirectory, streamOutput: streamOutput);
  }

  Future<ShortStatDto> stats(
      String localCheckoutDirectory, String oldTag, String newTag,
      {bool streamOutput = false}) {
    return StatsCommand(runner, oldTag: oldTag, newTag: newTag)
        .execute(localCheckoutDirectory, streamOutput: streamOutput);
  }

  Future<List<ShortLogDto>> contributionsByAuthor(String localCheckoutDirectory,
      {bool streamOutput = false}) {
    return ShortlogCommand(runner)
        .execute(localCheckoutDirectory, streamOutput: streamOutput);
  }

  Future<bool> cloneSpecificBranch(String localDirectoryToCloneInto,
      String repository, String branchToCheckout,
      {bool streamOutput = false}) async {
    try {
      await clone(localDirectoryToCloneInto, repository,
          streamOutput: streamOutput);

      String localCheckoutDirectory = localDirectoryToCloneInto +
          Platform.pathSeparator +
          GitUrlParser.parseRepositoryNameFromRepositoryUrl(repository);

      return checkout(localCheckoutDirectory, branchToCheckout,
          streamOutput: streamOutput);
    } on RwGitException {
      return false;
    }
  }

  /// Clones the specified [repository] into the [localDirectoryToCloneInto]
  /// and returns the statistics between the supplied [oldTag] and [newTag]
  Future<ShortStatDto> cloneAndGetStatistics(String localDirectoryToCloneInto,
      String repository, String oldTag, String newTag,
      {bool streamOutput = false}) async {
    try {
      await clone(localDirectoryToCloneInto, repository,
          streamOutput: streamOutput);

      String localCheckoutDirectory = localDirectoryToCloneInto +
          Platform.pathSeparator +
          GitUrlParser.parseRepositoryNameFromRepositoryUrl(repository);

      return stats(localCheckoutDirectory, oldTag, newTag,
          streamOutput: streamOutput);
    } on RwGitException {
      return ShortStatDto.defaultStats();
    }
  }

  /// Generic command execution to support all available git commands.
  Future<String> runCommand(String directory, List<String> args,
      {bool streamOutput = false}) async {
    final result = await runner.run('git', args,
        workingDirectory: directory, streamOutput: streamOutput);
    evaluateProcessResult(result);
    return result.stdout?.toString() ?? '';
  }
}
