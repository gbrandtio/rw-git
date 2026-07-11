import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

class ThrowingMockRunner implements ProcessRunner {
  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool streamOutput = false,
  }) async {
    throw Exception('Unexpected error executing git command');
  }

  @override
  Stream<String> runStream(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) {
    throw Exception('Unexpected error executing git command');
  }
}

class MockNullStdoutRunner implements ProcessRunner {
  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool streamOutput = false,
  }) async {
    return ProcessResult(0, 0, null, '');
  }

  @override
  Stream<String> runStream(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) {
    throw Exception('Unexpected stream error');
  }
}

void main() {
  group('New Git Commands Tests', () {
    late RwGit rwGit;
    late MockProcessRunner mockRunner;

    setUp(() {
      mockRunner = MockProcessRunner();
      rwGit = RwGit(runner: mockRunner);
    });

    test('branch returns list of branches', () async {
      mockRunner.setMockResult(
        'git',
        ['branch', 'extra_arg'],
        0,
        '  main\n* feature-branch\n  dev',
        '',
      );
      final result =
          (await rwGit.branch('my_dir', extraArgs: ['extra_arg'])).getOrThrow();
      expect(result.length, 3);
      expect(result[1].name, 'feature-branch');
      expect(result[1].isCurrent, true);
    });

    test('branch handles null stdout', () async {
      final nullGit = RwGit(runner: MockNullStdoutRunner());
      final result = (await nullGit.branch('my_dir')).getOrThrow();
      expect(result, []);
    });

    test('status returns short status', () async {
      mockRunner.setMockResult(
        'git',
        ['status', '--porcelain'],
        0,
        ' M file.txt\n?? new_file.txt',
        '',
      );
      final result = (await rwGit.status('my_dir')).getOrThrow();
      expect(result.unstagedChanges.length, 1);
      expect(result.untrackedFiles.length, 1);
    });

    test('pull returns true on success', () async {
      mockRunner.setMockResult(
        'git',
        ['pull', 'origin', 'main'],
        0,
        'Already up to date.',
        '',
      );
      final result = (await rwGit.pull(
        'my_dir',
        extraArgs: ['origin', 'main'],
      ))
          .getOrThrow();
      expect(result, true);
    });

    test('diff returns diff string', () async {
      mockRunner.setMockResult(
        'git',
        ['diff', 'file.txt'],
        0,
        'diff --git a/file.txt b/file.txt\n--- a/file.txt\n+++ b/file.txt\n@@ -1 +1 @@\n-old\n+new',
        '',
      );
      final result =
          (await rwGit.diff('my_dir', extraArgs: ['file.txt'])).getOrThrow();
      expect(result.files.length, 1);
    });

    test('merge returns true on success', () async {
      mockRunner.setMockResult(
        'git',
        ['merge', 'feature-branch'],
        0,
        'Merge made by the \'ort\' strategy.',
        '',
      );
      final result = (await rwGit.merge(
        'my_dir',
        extraArgs: ['feature-branch'],
      ))
          .getOrThrow();
      expect(result, true);
    });

    test('stash returns true on success', () async {
      mockRunner.setMockResult(
        'git',
        ['stash', 'push', '-m', 'msg'],
        0,
        'Saved working directory and index state msg',
        '',
      );
      final result = (await rwGit.stash(
        'my_dir',
        extraArgs: ['push', '-m', 'msg'],
      ))
          .getOrThrow();
      expect(result, true);
    });

    test('blame returns blame string', () async {
      mockRunner.setMockResult(
        'git',
        ['blame', '--date=iso', 'file.txt'],
        0,
        '1234abcd (Author 2021-01-01 00:00:00 +0000 1) content',
        '',
      );
      final result =
          (await rwGit.blame('my_dir', extraArgs: ['file.txt'])).getOrThrow();
      expect(result.lines.length, 1);
    });

    test('show returns show string', () async {
      mockRunner.setMockResult(
        'git',
        ['show', '-s', '--format=%H|%an|%ae|%aI|%s', 'HEAD'],
        0,
        '1234abcd|test|email|date|msg',
        '',
      );
      final result =
          (await rwGit.show('my_dir', extraArgs: ['HEAD'])).getOrThrow();
      expect(result.hash, '1234abcd');
    });

    test('branch handles failure', () async {
      mockRunner.setMockResult('git', ['branch'], 128, '', 'fatal error');
      try {
        (await rwGit.branch('my_dir')).getOrThrow();
        fail('Should throw');
      } catch (e) {
        expect(e, isA<RwGitException>());
      }
    });

    test('command handles generic exception', () async {
      final throwingGit = RwGit(runner: ThrowingMockRunner());
      final result = await throwingGit.branch('my_dir');
      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      try {
        result.getOrThrow();
        fail('Should throw');
      } catch (e) {
        expect(e, isA<RwGitException>());
        expect(
          (e as RwGitException).message,
          contains('Unexpected error executing git command'),
        );
      }
    });
  });
}
