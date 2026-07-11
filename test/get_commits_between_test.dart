// ignore_for_file: avoid_dynamic_calls, unnecessary_cast
import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

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
        (await rwGit.clone(testDir, repository)).getOrThrow();
        List<FileSystemEntity> clonedFiles = await Directory(
          testDir,
        ).list().toList();

        List<GitCommit> commitsBetweenTags = (await rwGit.getCommitsBetween(
          clonedFiles[0].uri.path,
          'v1.0.4',
          'v1.0.6',
        )).getOrThrow();

        expect(commitsBetweenTags.isNotEmpty, true);
      },
    );

    test(
      'will throw RwGitException if the provided tags or directory are invalid',
      () async {
        await Directory(testDir).create();
        try {
          (await rwGit.getCommitsBetween(
            testDir,
            'v1.0.0_extinct',
            'v1.0.1_extinct',
          )).getOrThrow();
          fail('Should have thrown RwGitException');
        } on RwGitException catch (e) {
          expect(e.exitCode != 0, true);
        }
      },
    );
  });
}
