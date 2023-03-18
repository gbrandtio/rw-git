import 'dart:convert';
import 'package:rw_git/src/models/short_stat_dto.dart';

/// ----------------------------------------------------------------------------
/// git_output_parser.dart
/// ----------------------------------------------------------------------------
/// Provides functionality for the parsing of the cmd output of git commands.
class GitOutputParser {
  /// Parses a stdout git output into a list. The parsing is achieved by
  /// splitting the data based on newline characters.
  static List<String> parseGitStdoutBasedOnNewLine(String gitStdout) {
    LineSplitter independentLineSplitter = const LineSplitter();
    List<String> independentLines = independentLineSplitter.convert(gitStdout);

    return independentLines;
  }

  /// Given a [List] that contains all the tags of a component, returns a new [List]
  /// that contains only the tags between the [oldTag] and the [newTag], including
  /// the [newTag] (but not the [oldTag]).
  static List<String> retrieveTagsInBetweenOf(List<String> allTags, String oldTag, String newTag) {
    List<String> inBetweenTags = List<String>.empty(growable: true);

    try {
      List<String> cornerTags = [oldTag, newTag];

      for (int i = 0; i < allTags.length; i++) {
        if (cornerTags.contains(allTags[i])) {
          cornerTags.remove(allTags[i]);

          for (int j = i + 1; j < allTags.length; j++) {
            inBetweenTags.add(allTags[i]);

            if (cornerTags.contains(allTags[i])) {
              break;
            }
          }
        }
      }
    } catch (e) {
      print(e.toString());
    }

    return inBetweenTags;
  }

  /// Parses the stdout of git --shortstat into the representation model.
  /// Example of git diff --shortstat:
  /// ```
  ///  3 files changed, 455 insertions(+), 12 deletions(-)
  /// ```
  static ShortStatDto parseGitShortStatStdout(String rawGitShortStats) {
    List<String> shortStatParts = List<String>.empty(growable: true);
    int numberOfChangedFiles = -1;
    int insertions = -1;
    int deletions = -1;

    try {
      shortStatParts = rawGitShortStats.split(',');
      for (int i = 0; i < shortStatParts.length; i++) {
        shortStatParts[i] = shortStatParts[i].trim();
      }

      numberOfChangedFiles = int.parse(shortStatParts[0].split(' ')[0]);
      insertions = int.parse(shortStatParts[1].split(' ')[0]);
      deletions = int.parse(shortStatParts[2].split(' ')[0]);
    } catch (e) {
      print(e.toString());
    }

    return ShortStatDto(numberOfChangedFiles, insertions, deletions);
  }
}
