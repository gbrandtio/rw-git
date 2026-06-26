import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

void main() {
  group('New Git Commands Tests', () {
    late RwGit rwGit;
    late MockProcessRunner mockRunner;

    setUp(() {
      mockRunner = MockProcessRunner();
      rwGit = RwGit(runner: mockRunner);
    });

    test('branch returns list of branches', () async {
      mockRunner.setMockResult('git', ['branch', 'extra_arg'], 0,
          '  main\n* feature-branch\n  dev', '');
      final result =
          (await rwGit.branch('my_dir', extraArgs: ['extra_arg'])).getOrThrow();
      expect(result, ['  main', '* feature-branch', '  dev']);
    });

    test('status returns short status', () async {
      mockRunner.setMockResult(
          'git', ['status', '--short'], 0, ' M file.txt\n?? new_file.txt', '');
      final result = (await rwGit.status('my_dir')).getOrThrow();
      expect(result, ' M file.txt\n?? new_file.txt');
    });

    test('pull returns true on success', () async {
      mockRunner.setMockResult(
          'git', ['pull', 'origin', 'main'], 0, 'Already up to date.', '');
      final result = (await rwGit.pull('my_dir', extraArgs: ['origin', 'main']))
          .getOrThrow();
      expect(result, true);
    });

    test('push returns true on success', () async {
      mockRunner.setMockResult(
          'git', ['push', 'origin', 'main'], 0, 'Everything up-to-date', '');
      final result = (await rwGit.push('my_dir', extraArgs: ['origin', 'main']))
          .getOrThrow();
      expect(result, true);
    });

    test('diff returns diff string', () async {
      mockRunner.setMockResult('git', ['diff', 'file.txt'], 0,
          'diff --git a/file.txt b/file.txt', '');
      final result =
          (await rwGit.diff('my_dir', extraArgs: ['file.txt'])).getOrThrow();
      expect(result, 'diff --git a/file.txt b/file.txt');
    });

    test('merge returns true on success', () async {
      mockRunner.setMockResult('git', ['merge', 'feature-branch'], 0,
          'Merge made by the \'ort\' strategy.', '');
      final result =
          (await rwGit.merge('my_dir', extraArgs: ['feature-branch']))
              .getOrThrow();
      expect(result, true);
    });

    test('stash returns true on success', () async {
      mockRunner.setMockResult('git', ['stash', 'push', '-m', 'msg'], 0,
          'Saved working directory and index state msg', '');
      final result =
          (await rwGit.stash('my_dir', extraArgs: ['push', '-m', 'msg']))
              .getOrThrow();
      expect(result, true);
    });

    test('blame returns blame string', () async {
      mockRunner.setMockResult('git', ['blame', 'file.txt'], 0,
          '1234abcd (Author 2021-01-01 1) content', '');
      final result =
          (await rwGit.blame('my_dir', extraArgs: ['file.txt'])).getOrThrow();
      expect(result, '1234abcd (Author 2021-01-01 1) content');
    });

    test('show returns show string', () async {
      mockRunner.setMockResult(
          'git', ['show', 'HEAD'], 0, 'commit 1234abcd\nAuthor: test', '');
      final result =
          (await rwGit.show('my_dir', extraArgs: ['HEAD'])).getOrThrow();
      expect(result, 'commit 1234abcd\nAuthor: test');
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
  });
}
