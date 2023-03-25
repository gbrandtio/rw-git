import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

final invalidResult = "INVALID";
final testDir = "TEST_STATS_DIR";
final repositoryWithTags = "https://github.com/google/material-design-lite";

void main() {
  late RwGit rwGit;

  // Actions execution before every test.
  setUp(() {
    rwGit = RwGit();
  });

  tearDown(() async {
    await Directory(testDir).delete(recursive: true);
  });

  /// Test group for [rwGit.stats()] function.
  group('stats', () {
    test('will create a ShortStatDto that will contain all the available data',
        () async {
      await rwGit.clone(testDir, repositoryWithTags);
      List<FileSystemEntity> clonedFiles =
          await Directory(testDir).list().toList();

      List<String> tags = await rwGit.fetchTags(clonedFiles[0].uri.path);
      ShortStatDto shortStatDto = await rwGit.stats(clonedFiles[0].uri.path,
          tags[tags.length - 2], tags[tags.length - 1]);

      expect(shortStatDto.numberOfChangedFiles >= 0, true);
      expect(shortStatDto.deletions >= 0, true);
      expect(shortStatDto.insertions >= 0, true);
    });

    test(
        'will result to a ShortStatDto with negative values if the git command fails',
        () async {
      await Directory(testDir).create();
      ShortStatDto shortStatDto =
          await rwGit.stats(testDir, "oldTag", "newTag");

      expect(shortStatDto.numberOfChangedFiles == -1, true);
      expect(shortStatDto.deletions == -1, true);
      expect(shortStatDto.insertions == -1, true);
    });
  });
}
