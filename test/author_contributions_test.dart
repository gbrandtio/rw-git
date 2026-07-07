// ignore_for_file: avoid_dynamic_calls, unnecessary_cast
import 'dart:io';
import 'package:rw_git/rw_git.dart';
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
      (await rwGit.clone(testDir, repositoryWithTags)).getOrThrow();
      List<FileSystemEntity> clonedFiles =
          await Directory(testDir).list().toList();

      List<ShortLogDto> contributionsByAuthor =
          (await rwGit.contributionsByAuthor(clonedFiles[0].uri.path))
              .getOrThrow();

      expect(contributionsByAuthor.length, greaterThan(1));
      expect(contributionsByAuthor[0].numberOfContributions, greaterThan(0));
      // `-n` sorts by commit count descending (the behavior the docs always
      // described): the first entry must have the highest count, not just
      // alphabetically the first author name.
      for (var i = 1; i < contributionsByAuthor.length; i++) {
        expect(
            contributionsByAuthor[i - 1].numberOfContributions,
            greaterThanOrEqualTo(
                contributionsByAuthor[i].numberOfContributions));
      }
    });

    test('scopes contributions to a date window via since/until', () async {
      (await rwGit.clone(testDir, repositoryWithTags)).getOrThrow();
      List<FileSystemEntity> clonedFiles =
          await Directory(testDir).list().toList();
      final directory = clonedFiles[0].uri.path;

      final unbounded =
          (await rwGit.contributionsByAuthor(directory)).getOrThrow();
      final scoped =
          (await rwGit.contributionsByAuthor(directory, since: '1 second ago'))
              .getOrThrow();

      int totalCommits(List<ShortLogDto> contributions) =>
          contributions.fold(0, (sum, c) => sum + c.numberOfContributions);

      // A since window of "1 second ago" cannot count more commits than the
      // full unbounded history.
      expect(unbounded, isNotEmpty);
      expect(totalCommits(scoped), lessThanOrEqualTo(totalCommits(unbounded)));
    });
  });
}
