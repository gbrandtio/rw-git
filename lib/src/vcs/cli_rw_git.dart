import '../../rw_git.dart';
import '../core/result.dart';
import '../commands/init_command.dart';
import '../commands/clone_command.dart';
import '../commands/checkout_command.dart';
import '../commands/fetch_tags_command.dart';
import '../commands/get_commits_command.dart';
import '../commands/stats_command.dart';
import '../commands/branch_command.dart';
import '../commands/status_command.dart';
import '../commands/pull_command.dart';
import '../commands/diff_command.dart';
import '../commands/merge_command.dart';
import '../commands/stash_command.dart';
import '../commands/blame_command.dart';
import '../commands/show_command.dart';
import '../commands/shortlog_command.dart';
import '../commands/is_git_repository_command.dart';
import 'base_rw_git.dart';

/// The existing CLI implementation using [ProcessRunner] and OS git.
class CliRwGit extends BaseRwGit {
  final ProcessRunner runner;

  CliRwGit({ProcessRunner? runner})
      : runner = runner ?? ProcessRunner.defaultRunner();

  @override
  Future<Result<bool, RwGitException>> init(String directoryToInit,
      {bool streamOutput = false}) {
    return InitCommand(runner)
        .execute(directoryToInit, streamOutput: streamOutput);
  }

  @override
  Future<Result<bool, RwGitException>> isGitRepository(String directoryToCheck,
      {bool streamOutput = false}) {
    return IsGitRepositoryCommand(runner)
        .execute(directoryToCheck, streamOutput: streamOutput);
  }

  @override
  Future<Result<bool, RwGitException>> clone(
      String localDirectoryToCloneInto, String repository,
      {bool streamOutput = false}) {
    return CloneCommand(runner, repository: repository)
        .execute(localDirectoryToCloneInto, streamOutput: streamOutput);
  }

  @override
  Future<Result<bool, RwGitException>> checkout(
      String localCheckoutDirectory, String branchToCheckout,
      {bool streamOutput = false}) {
    return CheckoutCommand(runner, branchToCheckout: branchToCheckout)
        .execute(localCheckoutDirectory, streamOutput: streamOutput);
  }

  @override
  Future<Result<List<GitTag>, RwGitException>> fetchTags(
      String localCheckoutDirectory,
      {bool streamOutput = false}) {
    return FetchTagsCommand(runner)
        .execute(localCheckoutDirectory, streamOutput: streamOutput);
  }

  @override
  Future<Result<List<GitCommit>, RwGitException>> getCommitsBetween(
      String localCheckoutDirectory, String firstTag, String secondTag,
      {bool streamOutput = false}) {
    return GetCommitsCommand(runner, firstTag: firstTag, secondTag: secondTag)
        .execute(localCheckoutDirectory, streamOutput: streamOutput);
  }

  @override
  Future<Result<ShortStatDto, RwGitException>> stats(
      String localCheckoutDirectory, String oldTag, String newTag,
      {bool streamOutput = false}) {
    return StatsCommand(runner, oldTag: oldTag, newTag: newTag)
        .execute(localCheckoutDirectory, streamOutput: streamOutput);
  }

  @override
  Future<Result<List<ShortLogDto>, RwGitException>> contributionsByAuthor(
      String localCheckoutDirectory,
      {String? since,
      String? until,
      bool streamOutput = false}) {
    final extraArgs = [
      if (since != null) '--since=$since',
      if (until != null) '--until=$until',
    ];
    return ShortlogCommand(runner).execute(localCheckoutDirectory,
        extraArgs: extraArgs, streamOutput: streamOutput);
  }

  @override
  Future<Result<List<GitBranch>, RwGitException>> branch(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) {
    return BranchCommand(runner)
        .execute(directory, extraArgs: extraArgs, streamOutput: streamOutput);
  }

  @override
  Future<Result<GitStatus, RwGitException>> status(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) {
    return StatusCommand(runner)
        .execute(directory, extraArgs: extraArgs, streamOutput: streamOutput);
  }

  @override
  Future<Result<bool, RwGitException>> pull(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) {
    return PullCommand(runner)
        .execute(directory, extraArgs: extraArgs, streamOutput: streamOutput);
  }

  @override
  Future<Result<GitDiff, RwGitException>> diff(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) {
    return DiffCommand(runner)
        .execute(directory, extraArgs: extraArgs, streamOutput: streamOutput);
  }

  @override
  Future<Result<bool, RwGitException>> merge(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) {
    return MergeCommand(runner)
        .execute(directory, extraArgs: extraArgs, streamOutput: streamOutput);
  }

  @override
  Future<Result<bool, RwGitException>> stash(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) {
    return StashCommand(runner)
        .execute(directory, extraArgs: extraArgs, streamOutput: streamOutput);
  }

  @override
  Future<Result<GitBlame, RwGitException>> blame(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) {
    return BlameCommand(runner)
        .execute(directory, extraArgs: extraArgs, streamOutput: streamOutput);
  }

  @override
  Future<Result<GitCommit, RwGitException>> show(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) {
    return ShowCommand(runner)
        .execute(directory, extraArgs: extraArgs, streamOutput: streamOutput);
  }
}
