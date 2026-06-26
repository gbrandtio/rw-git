import '../../rw_git.dart';
import '../core/result.dart';
import 'cli_rw_git.dart';
import 'libgit2_rw_git.dart';

/// ----------------------------------------------------------------------------
/// rw_git_facade.dart
/// ----------------------------------------------------------------------------
/// Offers a useful interface for executing various GIT commands and fetching a
/// pretty GIT result. This class acts as a Facade towards the outside world
/// and offers some common operations out-of-the-box (e.g., clone and checkout
/// a specific branch).
abstract class RwGit {
  String get invalidGitCommandResult;
  String get gitRepoIndicator;

  /// Factory constructor to support different Git runners.
  /// Uses [CliRwGit] by default which relies on `Process.run`.
  /// If [useLibGit2] is set to true, returns the FFI-based [LibGit2RwGit] for mobile support.
  factory RwGit({ProcessRunner? runner, bool useLibGit2 = false}) {
    if (useLibGit2) {
      return LibGit2RwGit();
    }
    return CliRwGit(runner: runner);
  }

  Future<Result<bool, RwGitException>> init(String directoryToInit,
      {bool streamOutput = false});
  Future<Result<bool, RwGitException>> isGitRepository(String directoryToCheck,
      {bool streamOutput = false});
  Future<Result<bool, RwGitException>> clone(
      String localDirectoryToCloneInto, String repository,
      {bool streamOutput = false});
  Future<Result<bool, RwGitException>> checkout(
      String localCheckoutDirectory, String branchToCheckout,
      {bool streamOutput = false});
  Future<Result<List<String>, RwGitException>> fetchTags(
      String localCheckoutDirectory,
      {bool streamOutput = false});
  Future<Result<List<String>, RwGitException>> getCommitsBetween(
      String localCheckoutDirectory, String firstTag, String secondTag,
      {bool streamOutput = false});
  Future<Result<ShortStatDto, RwGitException>> stats(
      String localCheckoutDirectory, String oldTag, String newTag,
      {bool streamOutput = false});
  Future<Result<List<ShortLogDto>, RwGitException>> contributionsByAuthor(
      String localCheckoutDirectory,
      {bool streamOutput = false});
  Future<Result<bool, RwGitException>> cloneSpecificBranch(
      String localDirectoryToCloneInto,
      String repository,
      String branchToCheckout,
      {bool streamOutput = false});
  Future<Result<ShortStatDto, RwGitException>> cloneAndGetStatistics(
      String localDirectoryToCloneInto,
      String repository,
      String oldTag,
      String newTag,
      {bool streamOutput = false});
  Future<Result<List<String>, RwGitException>> branch(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false});
  Future<Result<String, RwGitException>> status(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false});
  Future<Result<bool, RwGitException>> pull(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false});
  Future<Result<bool, RwGitException>> push(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false});
  Future<Result<String, RwGitException>> diff(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false});
  Future<Result<bool, RwGitException>> merge(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false});
  Future<Result<bool, RwGitException>> stash(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false});
  Future<Result<String, RwGitException>> blame(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false});
  Future<Result<String, RwGitException>> show(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false});

  Future<Result<String, RwGitException>> runCommand(
      String directory, List<String> args,
      {bool streamOutput = false});
}
