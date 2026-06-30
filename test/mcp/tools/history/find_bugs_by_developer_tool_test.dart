// ignore_for_file: avoid_dynamic_calls
import 'dart:convert';
import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:rw_git/src/mcp/tools/history/find_bugs_by_developer_tool.dart';
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
    print('TOOL ACTUAL CALL: $cmd');
    if (_mocks.containsKey(cmd)) {
      print('TOOL MOCK HIT');
      return ProcessResult(0, 0, _mocks[cmd], '');
    }
    print('TOOL MOCK MISS');
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

  late FindBugsByDeveloperTool tool;

  setUp(() {
    mockRunner = MockProcessRunner();
    tool = FindBugsByDeveloperTool(mockRunner);
  });

  group('FindBugsByDeveloperTool', () {
    test('has correct name and description', () {
      expect(tool.name, 'find_bugs_by_developer');
      expect(tool.description, isNotEmpty);
    });

    test('has correct schema', () {
      final schema = tool.inputSchema;
      expect((schema['required'] as List).contains('directory'), isTrue);
      expect((schema['required'] as List).contains('author'), isTrue);
    });

    test('returns error for malformed positiveRegex', () async {
      final result = await tool.execute({
        'directory': '.',
        'author': 'Alice',
        'positiveRegex': '(unclosed',
      });
      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['error'], contains('positiveRegex'));
    });

    test('returns error for malformed negativeRegex', () async {
      final result = await tool.execute({
        'directory': '.',
        'author': 'Alice',
        'negativeRegex': '[invalid',
      });
      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['error'], contains('negativeRegex'));
    });

    test('execute returns valid JSON with introduced bugs', () async {
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
          [
            'log',
            '-1',
            '--format=format:%H%x09%an%x09%ae%x09%aI%x09%s',
            '0123456789abcdef0123456789abcdef01234567'
          ],
          '0123456789abcdef0123456789abcdef01234567\tFixer\tfixer@author.com\t2023-01-02T12:00:00Z\tfix: fixed a critical bug\n');

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

      final resultJson = await tool.execute({
        'directory': './test_dir',
        'author': 'Target Author',
        'limit': 500,
        'positiveRegex': '\\b(fix|bug)\\b'
      });

      final result = jsonDecode(resultJson) as Map<String, dynamic>;
      expect(result['author_analyzed'], 'Target Author');
      expect(result['bugs_introduced_count'], 1);

      final bugs = result['bug_introductions'] as List;
      expect(bugs.length, 1);

      final bug = bugs[0] as Map<String, dynamic>;

      expect(bug['introducing_commit'],
          'fedcba9876543210fedcba9876543210fedcba98');
      expect(bug['fixing_commit'], '0123456789abcdef0123456789abcdef01234567');
      expect(bug['time_to_fix_in_hours'], 24);
    });
  });
}
