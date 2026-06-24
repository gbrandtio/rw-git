import 'dart:io';

import 'package:rw_git/rw_git.dart';

import 'package:test/test.dart';

void main() {
  group('ProcessRunner', () {
    test('StandardProcessRunner returns ProcessResult', () async {
      final runner = ProcessRunner.defaultRunner();
      final result = await runner.run('echo', ['hello']);
      expect(result.exitCode, 0);
      expect(result.stdout.toString().trim(), 'hello');
    });

    test(
        'StandardProcessRunner throws GitExecutableNotFoundException on ProcessException',
        () async {
      final runner = ProcessRunner.defaultRunner();
      expect(
        () => runner.run('non_existent_executable_123', []),
        throwsA(isA<GitExecutableNotFoundException>()),
      );
    });

    test('MockProcessRunner returns mocked result', () async {
      final runner = MockProcessRunner();
      runner.setMockResult('git', ['status'], 0, 'clean', '');

      final result = await runner.run('git', ['status']);
      expect(result.exitCode, 0);
      expect(result.stdout, 'clean');
    });

    test('MockProcessRunner returns error for unmocked result', () async {
      final runner = MockProcessRunner();
      final result = await runner.run('git', ['unknown']);
      expect(result.exitCode, 1);
      expect(result.stderr, contains('Mock result not found'));
    });
  });

  group('evaluateProcessResult', () {
    test('does nothing on exitCode 0', () {
      final result = ProcessResult(0, 0, 'ok', '');
      expect(() => evaluateProcessResult(result), returnsNormally);
    });

    test('throws GitBranchNotFoundException', () {
      final result = ProcessResult(
          0, 1, '', 'error: pathspec did not match any file(s) known to git');
      expect(() => evaluateProcessResult(result),
          throwsA(isA<GitBranchNotFoundException>()));
    });

    test('throws GitNotInitializedException', () {
      final result = ProcessResult(0, 128, '', 'fatal: not a git repository');
      expect(() => evaluateProcessResult(result),
          throwsA(isA<GitNotInitializedException>()));
    });

    test('throws GitMergeConflictException', () {
      final result = ProcessResult(0, 1, '', 'conflict');
      expect(() => evaluateProcessResult(result),
          throwsA(isA<GitMergeConflictException>()));
    });

    test('throws RwGitException for other errors', () {
      final result = ProcessResult(0, 2, '', 'some unknown error');
      expect(
          () => evaluateProcessResult(result), throwsA(isA<RwGitException>()));
    });
  });
}
