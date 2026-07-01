// ignore_for_file: avoid_dynamic_calls, unnecessary_cast
import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:rw_git/src/vcs/git_query.dart';
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
    if (await Directory(testDir).exists()) {
      await Directory(testDir).delete(recursive: true);
    }
  });

  group('cloneSpecificBranch', () {
    test(
        'will create a local directory and clone the specified repository inside'
        ' while also checking out the specified branch', () async {
      bool specificBranchClonedSuccessfully = (await rwGit.cloneSpecificBranch(
              testDir, validRemoteRepository, 'main'))
          .getOrThrow();
      expect(specificBranchClonedSuccessfully, true);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test(
        'will try to clone the remote repository and checkout an invalid branch',
        () async {
      try {
        (await rwGit.cloneSpecificBranch(
                testDir, validRemoteRepository, invalidBranch))
            .getOrThrow();
        fail('Should throw RwGitException for invalid branch');
      } on RwGitException catch (e) {
        expect(e.exitCode != 0, true);
      }
    });
    test('will throw RwGitException if clone fails', () async {
      try {
        (await rwGit.cloneSpecificBranch(
                testDir, 'invalid_repository_url_12345', branch))
            .getOrThrow();
        fail('Should throw RwGitException');
      } catch (e) {
        expect(e, isA<RwGitException>());
      }
    });

    test('will throw RwGitException if checkout fails', () async {
      final mockRunner = ProcessRunner.mock() as MockProcessRunner;
      mockRunner.setMockResult(
          'git', ['clone', validRemoteRepository], 0, '', '');
      mockRunner.setMockResult('git', ['checkout', invalidBranch], 128, '',
          'fatal: pathspec did not match any file(s) known to git');

      final mockGit = RwGit(runner: mockRunner);
      expect(
          () async => (await mockGit.cloneSpecificBranch(
                  testDir, validRemoteRepository, invalidBranch))
              .getOrThrow(),
          throwsA(isA<RwGitException>()));
    });
  });

  group('ReadOnlyGitQuery', () {
    test('will successfully execute a read-only git command', () async {
      (await rwGit.init(testDir)).getOrThrow();
      final gitQuery = ReadOnlyGitQuery(ProcessRunner.defaultRunner());
      String result = (await gitQuery.run(testDir, ['status'])).getOrThrow();
      expect(result.isNotEmpty, true);
      expect(result.contains('On branch'), true);
    });

    test('will reject non-allowlisted git subcommands', () async {
      final gitQuery = ReadOnlyGitQuery(ProcessRunner.defaultRunner());
      for (final args in [
        ['push', 'origin', 'main'],
        ['commit', '-m', 'msg'],
        ['invalid_command'],
        <String>[],
      ]) {
        expect(() => gitQuery.run(testDir, args), throwsArgumentError);
      }
    });

    test('will return Failure on a failing read-only command', () async {
      (await rwGit.init(testDir)).getOrThrow();
      final gitQuery = ReadOnlyGitQuery(ProcessRunner.defaultRunner());
      final result = await gitQuery.run(testDir, ['show', 'nonexistent-ref']);
      expect(result.isFailure, true);
      expect(() => result.getOrThrow(), throwsA(isA<RwGitException>()));
    });
  });
}
