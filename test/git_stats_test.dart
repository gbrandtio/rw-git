// ignore_for_file: avoid_dynamic_calls, unnecessary_cast
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
      (await rwGit.clone(testDir, repositoryWithTags)).getOrThrow();
      List<FileSystemEntity> clonedFiles =
          await Directory(testDir).list().toList();

      List<GitTag> tags =
          (await rwGit.fetchTags(clonedFiles[0].uri.path)).getOrThrow();
      ShortStatDto shortStatDto = (await rwGit.stats(clonedFiles[0].uri.path,
              tags[tags.length - 2].name, tags[tags.length - 1].name))
          .getOrThrow();

      expect(shortStatDto.numberOfChangedFiles >= 0, true);
      expect(shortStatDto.deletions >= 0, true);
      expect(shortStatDto.insertions >= 0, true);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('will throw RwGitException if the git command fails', () async {
      await Directory(testDir).create();
      try {
        (await rwGit.stats(testDir, "oldTag", "newTag")).getOrThrow();
        fail('Should have thrown RwGitException');
      } on RwGitException catch (e) {
        expect(e.exitCode != 0, true);
      }
    });
  });
}
