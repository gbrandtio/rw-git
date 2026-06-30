import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:rw_git/src/intelligence/history/algorithms/szz_algorithm.dart';
import 'package:test/test.dart';

class MockProcessRunner implements ProcessRunner {
  final Map<String, String> _mocks = {};

  void mockResult(String executable, List<String> arguments, String stdout) {
    _mocks['$executable ${arguments.join(' ')}'] = stdout;
  }

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool streamOutput = false,
  }) async {
    final cmd = '$executable ${arguments.join(' ')}';
    print('ACTUAL CALL: $cmd');
    if (_mocks.containsKey(cmd)) {
      print('MOCK HIT');
      return ProcessResult(0, 0, _mocks[cmd], '');
    }
    print('MOCK MISS');
    return ProcessResult(0, 0, '', '');
  }

  @override
  Stream<String> runStream(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) {
    throw UnimplementedError();
  }
}

void main() {
  late MockProcessRunner mockRunner;
  late SzzAlgorithm szz;

  setUp(() {
    mockRunner = MockProcessRunner();
    szz = SzzAlgorithm(mockRunner);
  });

  group('SzzAlgorithm', () {
    test('execute parses git blame correctly', () async {
      mockRunner.mockResult(
          'git',
          [
            'log',
            '-n',
            '500',
            '--grep=fix\\|bug\\|patch\\|issue\\|resolv',
            '-i',
            '--no-merges',
            '--format=format:%H%x09%aI%x09%s'
          ],
          '0123456789abcdef0123456789abcdef01234567\t2023-01-02T12:00:00Z\tfix: fixed a critical bug\n');

      mockRunner.mockResult(
          'git',
          ['rev-parse', '0123456789abcdef0123456789abcdef01234567^'],
          '1111222233334444555566667777888899990000\n');

      mockRunner.mockResult(
          'git',
          [
            'diff',
            '-M',
            '-w',
            '--ignore-blank-lines',
            '1111222233334444555566667777888899990000',
            '0123456789abcdef0123456789abcdef01234567'
          ],
          '--- a/test_file.dart\n+++ b/test_file.dart\n@@ -5,2 +5,0 @@\n- deleted_line_1\n- deleted_line_2\n');

      mockRunner.mockResult(
          'git',
          [
            'blame',
            '--date=iso-strict',
            '-l',
            '-w',
            '-C',
            '-C',
            '-M',
            '-L',
            '5,6',
            '1111222233334444555566667777888899990000',
            '--',
            'test_file.dart'
          ],
          'fedcba9876543210fedcba9876543210fedcba98 (Author Name 2023-01-01T12:00:00+00:00 5) deleted_line_1\n'
              'fedcba9876543210fedcba9876543210fedcba98 (Author Name 2023-01-01T12:00:00+00:00 6) deleted_line_2\n');

      final matches = await szz.execute('./test_dir', limit: '500');

      expect(matches.length, 2);
      expect(matches.first.introducingCommitHash,
          'fedcba9876543210fedcba9876543210fedcba98');
      expect(matches.first.introducingAuthor, 'Author Name');
      expect(matches.first.filePath, 'test_file.dart');
      expect(matches.first.fixingCommitHash,
          '0123456789abcdef0123456789abcdef01234567');
    });

    test('execute handles custom positiveRegex and negativeRegex correctly',
        () async {
      mockRunner.mockResult(
          'git',
          [
            'log',
            '-n',
            '500',
            '--grep=fix\\|bug\\|patch\\|issue\\|resolv',
            '-i',
            '--no-merges',
            '--format=format:%H%x09%aI%x09%s'
          ],
          '0123456789abcdef0123456789abcdef01234567\t2023-01-02T12:00:00Z\tfix: fixed a critical bug\n');

      mockRunner.mockResult(
          'git',
          ['rev-parse', '0123456789abcdef0123456789abcdef01234567^'],
          '1111222233334444555566667777888899990000\n');

      mockRunner.mockResult(
          'git',
          [
            'diff-tree',
            '--no-commit-id',
            '--name-only',
            '-r',
            '0123456789abcdef0123456789abcdef01234567'
          ],
          'test_file.dart\n');

      mockRunner.mockResult(
          'git',
          [
            'diff',
            '-M',
            '-w',
            '--ignore-blank-lines',
            '1111222233334444555566667777888899990000',
            '0123456789abcdef0123456789abcdef01234567'
          ],
          '--- a/test_file.dart\n+++ b/test_file.dart\n@@ -5 +5,0 @@\n- deleted_line_1\n');

      mockRunner.mockResult(
          'git',
          [
            'blame',
            '--date=iso-strict',
            '-l',
            '-w',
            '-C',
            '-C',
            '-M',
            '-L',
            '5,5',
            '1111222233334444555566667777888899990000',
            '--',
            'test_file.dart'
          ],
          'fedcba9876543210fedcba9876543210fedcba98 (Target Author 2023-01-01T12:00:00+00:00 5) deleted_line_1\n');

      mockRunner.mockResult(
          'git',
          [
            'log',
            '-1',
            '--format=format:%H%x09%an%x09%ae%x09%aI%x09%s',
            'fedcba9876543210fedcba9876543210fedcba98'
          ],
          'fedcba9876543210fedcba9876543210fedcba98\tTarget Author\ttarget@author.com\t2023-01-01T12:00:00Z\tfeat: introduced bug\n');

      mockRunner.mockResult(
          'git',
          [
            'log',
            '-1',
            '--format=format:%H%x09%an%x09%ae%x09%aI%x09%s',
            '0123456789abcdef0123456789abcdef01234567'
          ],
          '0123456789abcdef0123456789abcdef01234567\tFixer\tfixer@author.com\t2023-01-02T12:00:00Z\tfix: fixed a critical bug\n');

      final matches = await szz.execute('./test_dir',
          limit: '500', positiveRegex: '\\b(fix|bug)\\b');

      expect(matches.length, 1);
      expect(matches.first.introducingCommitHash,
          'fedcba9876543210fedcba9876543210fedcba98');
      expect(matches.first.introducingAuthor, 'Target Author');
      expect(matches.first.fixingCommitHash,
          '0123456789abcdef0123456789abcdef01234567');
    });
  });
}
