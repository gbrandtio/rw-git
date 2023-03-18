import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

final invalidResult = "INVALID";
final testDir = "TEST_TAGS_DIR";
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

  /// Test group for [rwGit.fetchTags()] function.
  group('fetchTags', () {
    test('will retrieve a list of tags from a valid git repository', () async {
      await rwGit.clone(testDir, repositoryWithTags);
      List<FileSystemEntity> clonedFiles =
          await Directory(testDir).list().toList();

      List<String> tags = await rwGit.fetchTags(clonedFiles[0].uri.path);
      bool isTagsMoreThanOne = tags.length > 1;

      expect(isTagsMoreThanOne, true);
    });
  });

  test('will return an empty list if the repository does not exist', () async {
    await Directory(testDir).create();
    List<String> tags = await rwGit.fetchTags(testDir);
    expect(tags.isEmpty, true);
  });
}
