import 'dart:io';
import 'package:rw_git/rw_git.dart';
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
          '--format=format:%H%x09%aI%x09%s',
        ],
        '0123456789abcdef0123456789abcdef01234567\t2023-01-02T12:00:00Z\tfix: fixed a critical bug\n',
      );

      mockRunner.mockResult('git', [
        'rev-parse',
        '0123456789abcdef0123456789abcdef01234567^',
      ], '1111222233334444555566667777888899990000\n');

      mockRunner.mockResult(
        'git',
        [
          'diff',
          '-M',
          '-w',
          '--ignore-blank-lines',
          '1111222233334444555566667777888899990000',
          '0123456789abcdef0123456789abcdef01234567',
        ],
        '--- a/test_file.dart\n+++ b/test_file.dart\n@@ -5,2 +5,0 @@\n- deleted_line_1\n- deleted_line_2\n',
      );

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
          'test_file.dart',
        ],
        'fedcba9876543210fedcba9876543210fedcba98 (Author Name 2023-01-01T12:00:00+00:00 5) deleted_line_1\n'
            'fedcba9876543210fedcba9876543210fedcba98 (Author Name 2023-01-01T12:00:00+00:00 6) deleted_line_2\n',
      );

      final matches = await szz.execute('./test_dir', limit: '500');

      expect(matches.length, 2);
      expect(
        matches.first.introducingCommitHash,
        'fedcba9876543210fedcba9876543210fedcba98',
      );
      expect(matches.first.introducingAuthor, 'Author Name');
      expect(matches.first.filePath, 'test_file.dart');
      expect(
        matches.first.fixingCommitHash,
        '0123456789abcdef0123456789abcdef01234567',
      );
    });

    test('forwards since/until as git flags on the fix-commit selection call '
        'only', () async {
      mockRunner.mockResult('git', [
        'log',
        '-n',
        '500',
        '--grep=fix\\|bug\\|patch\\|issue\\|resolv',
        '-i',
        '--no-merges',
        '--format=format:%H%x09%aI%x09%s',
        '--since=2024-01-01',
        '--until=2024-12-31',
      ], '');

      final matches = await szz.execute(
        './test_dir',
        limit: '500',
        since: '2024-01-01',
        until: '2024-12-31',
      );

      expect(matches, isEmpty);
    });

    test('parses -C -C filename columns and boundary (^) hashes instead of '
        'silently dropping them', () async {
      mockRunner.mockResult(
        'git',
        [
          'log',
          '--grep=fix\\|bug\\|patch\\|issue\\|resolv',
          '-i',
          '--no-merges',
          '--format=format:%H%x09%aI%x09%s',
        ],
        '0123456789abcdef0123456789abcdef01234567\t2023-01-02T12:00:00Z\tfix: fixed a critical bug\n',
      );

      mockRunner.mockResult('git', [
        'rev-parse',
        '0123456789abcdef0123456789abcdef01234567^',
      ], '1111222233334444555566667777888899990000\n');

      mockRunner.mockResult(
        'git',
        [
          'diff',
          '-M',
          '-w',
          '--ignore-blank-lines',
          '1111222233334444555566667777888899990000',
          '0123456789abcdef0123456789abcdef01234567',
        ],
        '--- a/test_file.dart\n+++ b/test_file.dart\n@@ -5,2 +5,0 @@\n- deleted_line_1\n- deleted_line_2\n',
      );

      // Line 5: -C -C attributed the line to content moved from another
      // file, so blame inserts a filename column between hash and paren.
      // Line 6: boundary commit — `^` prefix and a 39-char hash.
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
          'test_file.dart',
        ],
        'fedcba9876543210fedcba9876543210fedcba98 lib/moved_from.dart (Author Name 2023-01-01T12:00:00+00:00 5) deleted_line_1\n'
            '^edcba9876543210fedcba9876543210fedcba98 (Other Author 2022-12-31T08:00:00+02:00 6) deleted_line_2\n',
      );

      final matches = await szz.execute('./test_dir');

      expect(matches.length, 2);
      expect(
        matches[0].introducingCommitHash,
        'fedcba9876543210fedcba9876543210fedcba98',
      );
      expect(matches[0].introducingAuthor, 'Author Name');
      // Boundary marker stripped: `^` means exclusion in git rev syntax.
      expect(
        matches[1].introducingCommitHash,
        'edcba9876543210fedcba9876543210fedcba98',
      );
      expect(matches[1].introducingAuthor, 'Other Author');
    });

    test('throws GitOutputParseException on a malformed blame line', () async {
      mockRunner.mockResult(
        'git',
        [
          'log',
          '--grep=fix\\|bug\\|patch\\|issue\\|resolv',
          '-i',
          '--no-merges',
          '--format=format:%H%x09%aI%x09%s',
        ],
        '0123456789abcdef0123456789abcdef01234567\t2023-01-02T12:00:00Z\tfix: fixed a critical bug\n',
      );

      mockRunner.mockResult('git', [
        'rev-parse',
        '0123456789abcdef0123456789abcdef01234567^',
      ], '1111222233334444555566667777888899990000\n');

      mockRunner.mockResult(
        'git',
        [
          'diff',
          '-M',
          '-w',
          '--ignore-blank-lines',
          '1111222233334444555566667777888899990000',
          '0123456789abcdef0123456789abcdef01234567',
        ],
        '--- a/test_file.dart\n+++ b/test_file.dart\n@@ -5,1 +5,0 @@\n- deleted_line_1\n',
      );

      // A humanized date (e.g. from a stray --date override) must fail loud
      // rather than silently dropping the attribution.
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
          'test_file.dart',
        ],
        'fedcba9876543210fedcba9876543210fedcba98 (Author Name Sun Jan 1 12:00:00 2023 5) deleted_line_1\n',
      );

      expect(
        () => szz.execute('./test_dir'),
        throwsA(
          isA<GitOutputParseException>().having(
            (e) => e.offendingLine,
            'offendingLine',
            contains('fedcba98'),
          ),
        ),
      );
    });

    test('RA-SZZ line filter: a deleted line that re-appears as an added line '
        'is a move, not a fix, and is excluded from blame', () async {
      mockRunner.mockResult(
        'git',
        [
          'log',
          '-n',
          '500',
          '--grep=fix\\|bug\\|patch\\|issue\\|resolv',
          '-i',
          '--no-merges',
          '--format=format:%H%x09%aI%x09%s',
        ],
        '0123456789abcdef0123456789abcdef01234567\t2023-01-02T12:00:00Z\tfix: fixed a critical bug\n',
      );

      mockRunner.mockResult('git', [
        'rev-parse',
        '0123456789abcdef0123456789abcdef01234567^',
      ], '1111222233334444555566667777888899990000\n');

      // Line 5 is moved (identical content re-added, modulo indentation);
      // line 6 is a genuine bug-removing deletion. Only line 6 may be
      // blamed — attributing the moved line would blame the wrong commit.
      mockRunner.mockResult(
        'git',
        [
          'diff',
          '-M',
          '-w',
          '--ignore-blank-lines',
          '1111222233334444555566667777888899990000',
          '0123456789abcdef0123456789abcdef01234567',
        ],
        '--- a/test_file.dart\n'
            '+++ b/test_file.dart\n'
            '@@ -5,2 +5,1 @@\n'
            '-  validateInput(rawArguments);\n'
            '-  buggyOffByOne(index + 1);\n'
            '+    validateInput(rawArguments);\n',
      );

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
          '6,6',
          '1111222233334444555566667777888899990000',
          '--',
          'test_file.dart',
        ],
        'fedcba9876543210fedcba9876543210fedcba98 (Author Name 2023-01-01T12:00:00+00:00 6) buggyOffByOne(index + 1);\n',
      );

      final matches = await szz.execute('./test_dir', limit: '500');

      expect(matches.length, 1);
      expect(
        matches.first.introducingCommitHash,
        'fedcba9876543210fedcba9876543210fedcba98',
      );
    });

    test('RA-SZZ line filter keeps short boilerplate deletions: a re-added '
        '"}" is no evidence of a move', () async {
      mockRunner.mockResult(
        'git',
        [
          'log',
          '-n',
          '500',
          '--grep=fix\\|bug\\|patch\\|issue\\|resolv',
          '-i',
          '--no-merges',
          '--format=format:%H%x09%aI%x09%s',
        ],
        '0123456789abcdef0123456789abcdef01234567\t2023-01-02T12:00:00Z\tfix: fixed a critical bug\n',
      );

      mockRunner.mockResult('git', [
        'rev-parse',
        '0123456789abcdef0123456789abcdef01234567^',
      ], '1111222233334444555566667777888899990000\n');

      mockRunner.mockResult(
        'git',
        [
          'diff',
          '-M',
          '-w',
          '--ignore-blank-lines',
          '1111222233334444555566667777888899990000',
          '0123456789abcdef0123456789abcdef01234567',
        ],
        '--- a/test_file.dart\n'
            '+++ b/test_file.dart\n'
            '@@ -5 +5,1 @@\n'
            '-}\n'
            '+}\n',
      );

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
          'test_file.dart',
        ],
        'fedcba9876543210fedcba9876543210fedcba98 (Author Name 2023-01-01T12:00:00+00:00 5) }\n',
      );

      final matches = await szz.execute('./test_dir', limit: '500');

      expect(matches.length, 1);
    });

    test('RA-SZZ commit filter: an introducing commit whose subject is a '
        'refactoring is discarded — the buggy code predates it', () async {
      mockRunner.mockResult(
        'git',
        [
          'log',
          '-n',
          '500',
          '--grep=fix\\|bug\\|patch\\|issue\\|resolv',
          '-i',
          '--no-merges',
          '--format=format:%H%x09%aI%x09%s',
        ],
        '0123456789abcdef0123456789abcdef01234567\t2023-01-02T12:00:00Z\tfix: fixed a critical bug\n',
      );

      mockRunner.mockResult('git', [
        'rev-parse',
        '0123456789abcdef0123456789abcdef01234567^',
      ], '1111222233334444555566667777888899990000\n');

      mockRunner.mockResult(
        'git',
        [
          'diff',
          '-M',
          '-w',
          '--ignore-blank-lines',
          '1111222233334444555566667777888899990000',
          '0123456789abcdef0123456789abcdef01234567',
        ],
        '--- a/test_file.dart\n+++ b/test_file.dart\n@@ -5 +5,0 @@\n- deleted_line_1\n',
      );

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
          'test_file.dart',
        ],
        'fedcba9876543210fedcba9876543210fedcba98 (Author Name 2023-01-01T12:00:00+00:00 5) deleted_line_1\n',
      );

      mockRunner.mockResult(
        'git',
        [
          'log',
          '-1',
          '--format=format:%H%x09%an%x09%ae%x09%aI%x09%s',
          'fedcba9876543210fedcba9876543210fedcba98',
        ],
        'fedcba9876543210fedcba9876543210fedcba98\tAuthor Name\tauthor@x.com\t2023-01-01T12:00:00Z\trefactor: extract validation helpers\n',
      );

      final matches = await szz.execute('./test_dir', limit: '500');

      expect(matches, isEmpty);
    });

    test('execute handles custom positiveRegex and negativeRegex correctly', () async {
      mockRunner.mockResult(
        'git',
        [
          'log',
          '-n',
          '500',
          '--grep=fix\\|bug\\|patch\\|issue\\|resolv',
          '-i',
          '--no-merges',
          '--format=format:%H%x09%aI%x09%s',
        ],
        '0123456789abcdef0123456789abcdef01234567\t2023-01-02T12:00:00Z\tfix: fixed a critical bug\n',
      );

      mockRunner.mockResult('git', [
        'rev-parse',
        '0123456789abcdef0123456789abcdef01234567^',
      ], '1111222233334444555566667777888899990000\n');

      mockRunner.mockResult('git', [
        'diff-tree',
        '--no-commit-id',
        '--name-only',
        '-r',
        '0123456789abcdef0123456789abcdef01234567',
      ], 'test_file.dart\n');

      mockRunner.mockResult(
        'git',
        [
          'diff',
          '-M',
          '-w',
          '--ignore-blank-lines',
          '1111222233334444555566667777888899990000',
          '0123456789abcdef0123456789abcdef01234567',
        ],
        '--- a/test_file.dart\n+++ b/test_file.dart\n@@ -5 +5,0 @@\n- deleted_line_1\n',
      );

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
          'test_file.dart',
        ],
        'fedcba9876543210fedcba9876543210fedcba98 (Target Author 2023-01-01T12:00:00+00:00 5) deleted_line_1\n',
      );

      mockRunner.mockResult(
        'git',
        [
          'log',
          '-1',
          '--format=format:%H%x09%an%x09%ae%x09%aI%x09%s',
          'fedcba9876543210fedcba9876543210fedcba98',
        ],
        'fedcba9876543210fedcba9876543210fedcba98\tTarget Author\ttarget@author.com\t2023-01-01T12:00:00Z\tfeat: introduced bug\n',
      );

      mockRunner.mockResult(
        'git',
        [
          'log',
          '-1',
          '--format=format:%H%x09%an%x09%ae%x09%aI%x09%s',
          '0123456789abcdef0123456789abcdef01234567',
        ],
        '0123456789abcdef0123456789abcdef01234567\tFixer\tfixer@author.com\t2023-01-02T12:00:00Z\tfix: fixed a critical bug\n',
      );

      final matches = await szz.execute(
        './test_dir',
        limit: '500',
        positiveRegex: '\\b(fix|bug)\\b',
      );

      expect(matches.length, 1);
      expect(
        matches.first.introducingCommitHash,
        'fedcba9876543210fedcba9876543210fedcba98',
      );
      expect(matches.first.introducingAuthor, 'Target Author');
      expect(
        matches.first.fixingCommitHash,
        '0123456789abcdef0123456789abcdef01234567',
      );
    });
  });
}
