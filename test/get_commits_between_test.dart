import 'dart:io';

import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

final invalidResult = "INVALID";
final testDir = "COMMITS_BETWEEN_TEST_DIR";
final repository = "https://github.com/google/material-design-lite";

void main() {
  late RwGit rwGit;

  setUp(() {
    rwGit = RwGit();
  });

  tearDown(() async {
    await Directory(testDir).delete(recursive: true);
  });

  /// Test group for [rwGit.getCommitsBetween()] function.
  group('getCommitsBetween', () {
    test(
        'output count will be greater than 0, if the provided repository and tags are valid',
            () async {
          await rwGit.clone(testDir, repository);
          List<String> commitsBetweenTags = await rwGit.getCommitsBetween(
              testDir, 'v1.0.4', 'v1.0.6');

          expect(commitsBetweenTags.isNotEmpty, true);
        });

    test(
        'output length will be 0, if the provided tags or directory are invalid',
            () async {
          List<String> commitsBetweenTags = await rwGit.getCommitsBetween(
              './extinct', 'v1.0.0_extinct', 'v1.0.1_extinct');

          expect(commitsBetweenTags.length, 0);
        });
  });
}
