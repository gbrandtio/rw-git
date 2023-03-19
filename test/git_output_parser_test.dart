import 'package:rw_git/rw_git.dart';
import 'package:rw_git/src/git_service/rw_git_parser.dart';
import 'package:test/test.dart';

void main() {
  /// Test group for [parseGitStdoutBasedOnNewLine] function.
  group('parseGitStdoutBasedOnNewLine', () {
    test('will split a string into a list based on new line characters', () {
      final strWithNewLineWindowsCharacters = "AA \r\n BBB \r\n CCC";
      final strWithNewLineLinuxCharacters = "AAA \n BBB \n CCC";
      final strWithNewLineMacOSCharacters = "AAA \r BBB \r CCC";

      List<String> windowsLines = RwGitParser.parseGitStdoutBasedOnNewLine(
          strWithNewLineWindowsCharacters);
      List<String> linuxLines = RwGitParser.parseGitStdoutBasedOnNewLine(
          strWithNewLineLinuxCharacters);
      List<String> macosLines = RwGitParser.parseGitStdoutBasedOnNewLine(
          strWithNewLineMacOSCharacters);

      for (int i = 0; i < 3; i++) {
        expect(windowsLines[i].isEmpty, false);
        expect(linuxLines[i].isEmpty, false);
        expect(macosLines[i].isEmpty, false);
      }
    });

    test('will return an empty list, if passed an empty string', () {
      final emptyString = "";
      List<String> mustBeAnEmptyList =
          RwGitParser.parseGitStdoutBasedOnNewLine(emptyString);
      expect(mustBeAnEmptyList.isEmpty, true);
    });
  });

  /// Test group for [retrieveTagsInBetweenOf] function.
  group('retrieveTagsInBetweenOf', () {
    List<String> fakeTagsEvenNumber = List.empty(growable: true);
    List<String> fakeTagsOddNumber = List.empty(growable: true);

    setUp(() {
      fakeTagsEvenNumber = ["v1.0.0", "v1.0.1", "v1.0.2", "v1.0.3"];
      fakeTagsOddNumber = ["v1.0.0", "v1.0.1", "v1.0.2", "v1.0.3", "v1.0.4"];
    });

    test(
        'will return all the values between the supplied tags of even number, including the last tag',
        () {
      List<String> tagsInBetween = RwGitParser.retrieveTagsInBetweenOf(
          fakeTagsEvenNumber, "v1.0.1", "v1.0.3");
      expect(tagsInBetween.length, 2);
      expect(tagsInBetween[tagsInBetween.length - 1], "v1.0.3");
    });

    test(
        'will return only one tag, which will be the last one, if there are not any in between tags',
        () {
      List<String> tagsInBetween = RwGitParser.retrieveTagsInBetweenOf(
          fakeTagsEvenNumber, "v1.0.1", "v1.0.2");
      expect(tagsInBetween.length, 1);
      expect(tagsInBetween[0], "v1.0.2");
    });

    test(
        'will return all the values between the supplied tags of odd number, including the last tag',
        () {
      List<String> tagsInBetween = RwGitParser.retrieveTagsInBetweenOf(
          fakeTagsOddNumber, "v1.0.1", "v1.0.3");

      expect(tagsInBetween.length, 2);
      expect(tagsInBetween[tagsInBetween.length - 1], "v1.0.3");
    });

    test(
        'will return a list containing all the tags till the end, if the end tag does not exist (for even number of tags)',
        () {
      List<String> tagsInBetween = RwGitParser.retrieveTagsInBetweenOf(
          fakeTagsEvenNumber, "v1.0.0", "v1.0.7");
      expect(tagsInBetween.length, 3);
    });

    test(
        'will return a list containing all the tags till the end, if the end tag does not exist (for odd number of tags)',
        () {
      List<String> tagsInBetween = RwGitParser.retrieveTagsInBetweenOf(
          fakeTagsOddNumber, "v1.0.0", "v1.0.7");
      expect(tagsInBetween.length, 4);
    });

    test(
        'will return a list containing all the tags till the end, when the new tag is the last tag (for even number of tags)',
        () {
      List<String> tagsInBetween = RwGitParser.retrieveTagsInBetweenOf(
          fakeTagsEvenNumber, "v1.0.1", "v1.0.3");
      expect(tagsInBetween.length, 2);
      expect(tagsInBetween[tagsInBetween.length - 1], "v1.0.3");
    });

    test(
        'will return a list containing all the tags till the end, when the new tag is the last tag (for odd number of tags)',
        () {
      List<String> tagsInBetween = RwGitParser.retrieveTagsInBetweenOf(
          fakeTagsOddNumber, "v1.0.1", "v1.0.4");
      expect(tagsInBetween.length, 3);
      expect(tagsInBetween[tagsInBetween.length - 1], "v1.0.4");
    });
  });

  /// Test group for [parseGitShortStatStdout] function.
  group('parseGitShortStatStdout', () {
    test('will parse a sample line into a ShortStatDto object', () {
      final sampleShortStatRawString =
          " 3 files changed, 455 insertions(+), 12 deletions(-) ";
      ShortStatDto shortStatDto =
          RwGitParser.parseGitShortStatStdout(sampleShortStatRawString);

      expect(shortStatDto.numberOfChangedFiles, 3);
      expect(shortStatDto.insertions, 455);
      expect(shortStatDto.deletions, 12);
    });

    test(
        'will have default values for all properties if the line failed to be parsed',
        () {
      final sampleShortStatRawString =
          " 3fileschanged455insertions(+)12deletions(-) ";
      ShortStatDto shortStatDto =
          RwGitParser.parseGitShortStatStdout(sampleShortStatRawString);

      expect(shortStatDto.numberOfChangedFiles, -1);
      expect(shortStatDto.insertions, -1);
      expect(shortStatDto.deletions, -1);
    });
  });
}
