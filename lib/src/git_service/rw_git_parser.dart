import 'dart:convert';
import 'package:rw_git/src/models/short_log_dto.dart';
import 'package:rw_git/src/models/short_stat_dto.dart';

/// ----------------------------------------------------------------------------
/// rw_git_parser.dart
/// ----------------------------------------------------------------------------
/// Provides functionality for the parsing of the cmd output of git commands.
class RwGitParser {
  /// Parses a stdout git output into a list. The parsing is achieved by
  /// splitting the data based on newline characters.
  static List<String> parseGitStdoutBasedOnNewLine(String gitStdout) {
    LineSplitter independentLineSplitter = const LineSplitter();
    List<String> independentLines = independentLineSplitter.convert(gitStdout);
    independentLines =
        independentLines.where((element) => element.isNotEmpty).toList();

    return independentLines;
  }

  /// Given a [List] that contains all the tags of a component, returns a new [List]
  /// that contains only the tags between the [oldTag] and the [newTag], including
  /// the [newTag] (but not the [oldTag]).
  static List<String> retrieveTagsInBetweenOf(
      List<String> allTags, String oldTag, String newTag) {
    int oldTagIndex = allTags.indexOf(oldTag) + 1;
    int newTagIndex = allTags.indexOf(newTag);

    newTagIndex = newTagIndex == -1 ? allTags.length - 1 : newTagIndex;
    // Include the element at [newTagIndex] in the resulting sublist.
    newTagIndex++;

    List<String> inBetweenTags = allTags.sublist(oldTagIndex, newTagIndex);
    return inBetweenTags;
  }

  /// Parses the stdout of git diff --shortstat into the representation model.
  /// Example of git diff --shortstat:
  /// ```
  ///  3 files changed, 455 insertions(+), 12 deletions(-)
  /// ```
  static ShortStatDto parseGitShortStatStdout(String rawGitShortStats) {
    int numberOfChangedFiles = -1;
    int insertions = -1;
    int deletions = -1;

    try {
      List<String> shortStatParts = rawGitShortStats.split(',');
      for (int i = 0; i < shortStatParts.length; i++) {
        shortStatParts[i] = shortStatParts[i].trim();
      }

      numberOfChangedFiles = int.parse(shortStatParts[0].split(' ')[0]);
      insertions = int.parse(shortStatParts[1].split(' ')[0]);
      deletions = int.parse(shortStatParts[2].split(' ')[0]);
    } catch (e) {
      numberOfChangedFiles = -1;
      insertions = -1;
      deletions = -1;
    }

    return ShortStatDto(numberOfChangedFiles, insertions, deletions);
  }

  /// Parses the stdout of git shortlog -s into the representation model.
  /// Example of git shortlog -s:
  /// ```
  ///  (80) Ioannis Brant-Ioannidis
  /// ```
  static ShortLogDto parseGitShortLogStdout(String rawGitShortLog) {
    int numberOfContributions = -1;
    String authorName = "";

    try {
      List<String> shortLogParts = rawGitShortLog.trim().split(" ");
      numberOfContributions = int.parse(shortLogParts[0]);
      authorName = shortLogParts[1];
    } catch (e) {
      numberOfContributions = -1;
      authorName = "";
    }

    return ShortLogDto(numberOfContributions, authorName);
  }
}
