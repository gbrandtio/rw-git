import 'dart:io';
import '../../../rw_git.dart';
import 'package:git/git.dart' as git_service;
import '../../models/short_log_dto.dart';

/// ----------------------------------------------------------------------------
/// git_stats.dart
/// ----------------------------------------------------------------------------
/// Provides GIT methods that enable the statistics gathering for a GIT repository.
class GitStats {
  static final GitStats _gitStats = GitStats._internal();

  /// Factory constructor to support the singleton pattern.
  factory GitStats() {
    return _gitStats;
  }

  /// Private constructor to support the singleton pattern.
  GitStats._internal();

  /// `git diff --shortstat oldTag newTag` to fetch statistics related to
  /// insertions, deletions and number of changed files between two tags.
  /// In case of success will return a [ShortStatDto] object with the available data,
  /// whereas an object with the default values otherwise.
  Future<ShortStatDto> stats(
      String localCheckoutDirectory, String oldTag, newTag) async {
    String rawResult = "";

    ProcessResult processResult = await git_service.runGit(
        ['diff', '--shortstat', oldTag, newTag],
        throwOnError: false,
        echoOutput: false,
        processWorkingDir: localCheckoutDirectory);

    rawResult = processResult.stdout;
    return RwGitParser.parseGitShortStatStdout(rawResult);
  }

  /// `git shortlog -s` to fetch author contributions.
  /// In case of success will return a [ShortLogDto] object with the available
  /// data, whereas an object with the default values otherwise.
  Future<List<ShortLogDto>> contributionsByAuthor(
      String localCheckoutDirectory) async {
    ProcessResult processResult = await Process.run(
        'git', ['shortlog', 'HEAD', '-s'],
        workingDirectory: localCheckoutDirectory);

    List<String> rawList =
        RwGitParser.parseGitStdoutBasedOnNewLine(processResult.stdout);
    List<ShortLogDto> contributionsByAuthor =
        rawList.map((e) => RwGitParser.parseGitShortLogStdout(e)).toList();

    return contributionsByAuthor;
  }
}
