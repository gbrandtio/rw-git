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
          testDir, validRemoteRepository, 'main');
      expect(specificBranchClonedSuccessfully, true);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test(
        'will try to clone the remote repository and checkout an invalid branch',
        () async {
      try {
        await rwGit.cloneSpecificBranch(
            testDir, validRemoteRepository, invalidBranch);
        fail('Should throw RwGitException for invalid branch');
      } on RwGitException catch (e) {
        expect(e.exitCode != 0, true);
      }
    });
    test('will return false if clone throws RwGitException', () async {
      try {
        await rwGit.cloneSpecificBranch(
            testDir, 'invalid_repository_url_12345', branch);
        fail('Should return false, not throw or succeed');
      } on RwGitException catch (_) {
        fail('Should catch RwGitException and return false');
      } catch (e) {
        expect(e, isNot(isA<RwGitException>()));
      }
    });

    test('will return false if checkout throws RwGitException', () async {
      final mockRunner = ProcessRunner.mock() as MockProcessRunner;
      mockRunner.setMockResult(
          'git', ['clone', validRemoteRepository], 0, '', '');
      mockRunner.setMockResult('git', ['checkout', invalidBranch], 128, '',
          'fatal: pathspec did not match any file(s) known to git');

      final mockGit = RwGit(runner: mockRunner);
      final result = await mockGit.cloneSpecificBranch(
          testDir, validRemoteRepository, invalidBranch);
      expect(result, false);
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
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('will return default stats if clone fails', () async {
      ShortStatDto shortStatDto = await rwGit.cloneAndGetStatistics(
          testDir, 'invalid_repository_url_12345', 'v1', 'v2');
      expect(shortStatDto.insertions, -1);
      expect(shortStatDto.deletions, -1);
      expect(shortStatDto.numberOfChangedFiles, -1);
    });

    test('will return default stats if stats throws RwGitException', () async {
      final mockRunner = ProcessRunner.mock() as MockProcessRunner;
      mockRunner.setMockResult('git', ['clone', repositoryWithTags], 0, '', '');
      mockRunner.setMockResult(
          'git',
          ['diff', '--shortstat', 'v1.0.4', 'invalid_tag'],
          128,
          '',
          'fatal: ambiguous argument');

      final mockGit = RwGit(runner: mockRunner);
      final result = await mockGit.cloneAndGetStatistics(
          testDir, repositoryWithTags, 'v1.0.4', 'invalid_tag');
      expect(result.insertions, -1);
    });
  });

  group('runCommand', () {
    test('will successfully execute a generic git command', () async {
      await rwGit.init(testDir);
      String result = await rwGit.runCommand(testDir, ['status']);
      expect(result.isNotEmpty, true);
      expect(result.contains('On branch'), true);
    });

    test('will throw exception on invalid git command', () async {
      await rwGit.init(testDir);
      try {
        await rwGit.runCommand(testDir, ['invalid_command']);
        fail('Should throw an exception');
      } on RwGitException catch (e) {
        expect(e.exitCode != 0, true);
      }
    });
  });
}
