import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

final invalidResult = "INVALID";
final testDir = "CLONE_SPECIFIC_BRANCH_TEST_DIR";
final validRemoteRepository = "https://github.com/gbrandtio/rw-git";
final repositoryWithTags = "https://github.com/google/material-design-lite";
final String branch = "flaky-tests-support-branch";
final String invalidBranch = "invalid-branch";

void main() {
  late RwGit rwGit;

  setUp(() {
    rwGit = RwGit();
  });

  tearDown(() async {
    await Directory(testDir).delete(recursive: true);
  });

  group('cloneSpecificBranch', () {
    test(
        'will create a local directory and clone the specified repository inside'
        ' while also checking out the specified branch', () async {
      bool specificBranchClonedSuccessfully = await rwGit.cloneSpecificBranch(
          testDir, validRemoteRepository, branch);
      expect(specificBranchClonedSuccessfully, true);
    });

    test(
        'will try to clone the remote repository and checkout an invalid branch',
        () async {
      bool specificBranchClonedSuccessfully = await rwGit.cloneSpecificBranch(
          testDir, validRemoteRepository, invalidBranch);
      expect(specificBranchClonedSuccessfully, false);
    });
  });

  group('cloneAndGetStatistics', () {
    test('will create a ShortStatDto that will contain all the available data',
        () async {
      String oldTag = "v1.0.4";
      String newTag = "v1.3.0";

      ShortStatDto shortStatDto = await rwGit.cloneAndGetStatistics(
          testDir, repositoryWithTags, oldTag, newTag);

      expect(shortStatDto.insertions >= 0, true);
      expect(shortStatDto.deletions >= 0, true);
      expect(shortStatDto.numberOfChangedFiles >= 0, true);
    });
  });
}
