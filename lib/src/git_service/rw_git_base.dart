import 'package:rw_git/src/git_service/common/git_common.dart';
import 'package:rw_git/src/git_service/statistics/git_stats.dart';

/// ----------------------------------------------------------------------------
/// rw_git_base.dart
/// ----------------------------------------------------------------------------
/// Offers a useful interface for executing various GIT commands and fetching a
/// pretty GIT result.
class RwGit {
  final invalidGitCommandResult = "INVALID";
  final gitRepoIndicator = ".git";

  final GitCommon gitCommon = GitCommon();
  final GitStats gitStats = GitStats();
}
