import '../../rw_git.dart';
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

  Future<bool> init(String directoryToInit, {bool streamOutput = false});
  Future<bool> isGitRepository(String directoryToCheck,
      {bool streamOutput = false});
  Future<bool> clone(String localDirectoryToCloneInto, String repository,
      {bool streamOutput = false});
  Future<bool> checkout(String localCheckoutDirectory, String branchToCheckout,
      {bool streamOutput = false});
  Future<List<String>> fetchTags(String localCheckoutDirectory,
      {bool streamOutput = false});
  Future<List<String>> getCommitsBetween(
      String localCheckoutDirectory, String firstTag, String secondTag,
      {bool streamOutput = false});
  Future<ShortStatDto> stats(
      String localCheckoutDirectory, String oldTag, String newTag,
      {bool streamOutput = false});
  Future<List<ShortLogDto>> contributionsByAuthor(String localCheckoutDirectory,
      {bool streamOutput = false});
  Future<bool> cloneSpecificBranch(String localDirectoryToCloneInto,
      String repository, String branchToCheckout,
      {bool streamOutput = false});
  Future<ShortStatDto> cloneAndGetStatistics(String localDirectoryToCloneInto,
      String repository, String oldTag, String newTag,
      {bool streamOutput = false});
  Future<String> runCommand(String directory, List<String> args,
      {bool streamOutput = false});
}
