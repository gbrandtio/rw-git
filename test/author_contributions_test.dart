import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:rw_git/src/models/short_log_dto.dart';
import 'package:test/test.dart';

final invalidResult = "INVALID";
final testDir = "TEST_CONTRIBUTIONS_DIR";
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

  /// Test group for [rwGit.authorContributions()] function.
  group('authorContributions', () {
    test('will create a ShortLogDto that will contain all the available data',
        () async {
      await rwGit.clone(testDir, repositoryWithTags);
      List<FileSystemEntity> clonedFiles =
          await Directory(testDir).list().toList();

      List<ShortLogDto> contributionsByAuthor =
          await rwGit.contributionsByAuthor(clonedFiles[0].uri.path);

      expect(contributionsByAuthor.length, greaterThan(1));
      expect(contributionsByAuthor[0].numberOfContributions, greaterThan(0));
      expect(contributionsByAuthor[0].authorName, "Aaron");
    });
  });
}
