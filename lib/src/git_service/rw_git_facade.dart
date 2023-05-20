import 'dart:io';

import 'package:rw_git/rw_git.dart';
import 'package:rw_git/src/git_service/common/git_common.dart';
import 'package:rw_git/src/git_service/parsers/git_url_parser.dart';
import 'package:rw_git/src/git_service/statistics/git_stats.dart';

/// ----------------------------------------------------------------------------
/// rw_git_facade.dart
/// ----------------------------------------------------------------------------
/// Offers a useful interface for executing various GIT commands and fetching a
/// pretty GIT result. This class acts as a Facade towards the outside world
/// and offers some common operations out-of-the-box (e.g., clone and checkout
/// a specific branch).
class RwGit {
  final invalidGitCommandResult = "INVALID";
  final gitRepoIndicator = ".git";

  final GitCommon gitCommon = GitCommon();
  final GitStats gitStats = GitStats();

  /// Clones the provided [repository] and checks out the provided [branchToCheckout].
  /// The repository will be available locally at the [localDirectoryToCloneInto].
  /// If both ```clone``` and ```checkout``` operations are successful, this method
  /// will return true, otherwise false.
  Future<bool> cloneSpecificBranch(String localDirectoryToCloneInto,
      String repository, String branchToCheckout) async {
    bool clonedSuccessfully =
        await gitCommon.clone(localDirectoryToCloneInto, repository);

    bool checkedOutSuccessfully = false;
    if (clonedSuccessfully) {
      // Navigate inside the cloned directory
      String localCheckoutDirectory = localDirectoryToCloneInto +
          Platform.pathSeparator +
          GitUrlParser.parseRepositoryNameFromRepositoryUrl(repository);

      checkedOutSuccessfully =
          await gitCommon.checkout(localCheckoutDirectory, branchToCheckout);
    }

    if (clonedSuccessfully && checkedOutSuccessfully) {
      return true;
    } else {
      return false;
    }
  }

  /// Clones the specified [repository] into the [localDirectoryToCloneInto]
  /// and returns the statistics between the supplied [oldTag] and [newTag]
  /// if the operations are successful. If ```clone``` or statistics
  /// fetching/parsing has failed a [ShortStatDto] with default values
  /// will be returned.
  Future<ShortStatDto> cloneAndGetStatistics(String localDirectoryToCloneInto,
      String repository, String oldTag, String newTag) async {
    bool clonedSuccessfully =
        await gitCommon.clone(localDirectoryToCloneInto, repository);

    ShortStatDto shortStatDto = ShortStatDto.defaultStats();
    if (clonedSuccessfully) {
      // Navigate inside the cloned directory
      String localCheckoutDirectory = localDirectoryToCloneInto +
          Platform.pathSeparator +
          GitUrlParser.parseRepositoryNameFromRepositoryUrl(repository);

      shortStatDto =
          await gitStats.stats(localCheckoutDirectory, oldTag, newTag);
    }

    return shortStatDto;
  }
}
