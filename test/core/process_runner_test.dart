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

    test('StandardProcessRunner run with streamOutput=true', () async {
      final runner = ProcessRunner.defaultRunner();
      final result = await runner.run('echo', ['hello'], streamOutput: true);
      expect(result.exitCode, 0);
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

    test('MockProcessRunner returns mocked result with streamOutput=true',
        () async {
      final runner = MockProcessRunner();
      runner.setMockResult('git', ['status'], 0, 'clean', '');

      final result = await runner.run('git', ['status'], streamOutput: true);
      expect(result.exitCode, 0);
    });

    test('MockProcessRunner returns error for unmocked result', () async {
      final runner = MockProcessRunner();
      final result = await runner.run('git', ['unknown']);
      expect(result.exitCode, 1);
      expect(result.stderr, contains('Mock result not found'));
    });

    test('StandardProcessRunner runStream returns Stream of ProcessResult',
        () async {
      final runner = ProcessRunner.defaultRunner();
      final stream = runner.runStream('echo', ['hello\nworld']);
      final lines = await stream.toList();
      expect(lines, contains('hello'));
      expect(lines, contains('world'));
    });

    test('StandardProcessRunner runStream throws on failure', () async {
      final runner = ProcessRunner.defaultRunner();
      final stream = runner.runStream('ls', ['/non_existent_directory_123']);
      expect(
        stream.toList(),
        throwsA(isA<RwGitException>()),
      );
    });

    test(
        'StandardProcessRunner runStream throws GitExecutableNotFoundException on ProcessException',
        () async {
      final runner = ProcessRunner.defaultRunner();
      expect(
        runner.runStream('non_existent_executable_123', []).toList(),
        throwsA(isA<GitExecutableNotFoundException>()),
      );
    });

    test('MockProcessRunner runStream returns mocked stream', () async {
      final runner = MockProcessRunner();
      runner.setMockResult('git', ['log', '-p'], 0, 'line1\nline2\nline3', '');

      final stream = runner.runStream('git', ['log', '-p']);
      final lines = await stream.toList();
      expect(lines.length, 3);
      expect(lines[0], 'line1');
      expect(lines[1], 'line2');
      expect(lines[2], 'line3');
    });

    test('MockProcessRunner runStream evaluates ProcessResult if exitCode != 0',
        () async {
      final runner = MockProcessRunner();
      runner.setMockResult(
          'git', ['badcmd'], 1, 'output', 'fatal: not a git repository');

      expect(
        runner.runStream('git', ['badcmd']).toList(),
        throwsA(isA<GitNotInitializedException>()),
      );
    });

    test('MockProcessRunner runStream returns error for unmocked stream',
        () async {
      final runner = MockProcessRunner();
      final stream = runner.runStream('git', ['unknown']);
      expect(
        stream.toList(),
        throwsA(isA<RwGitException>()),
      );
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
