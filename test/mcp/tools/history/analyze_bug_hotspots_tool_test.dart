// ignore_for_file: avoid_dynamic_calls
import 'dart:convert';
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
    if (_mocks.containsKey(cmd)) {
      return ProcessResult(0, 0, _mocks[cmd], '');
    }
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
  late AnalyzeBugHotspotsTool tool;

  setUp(() {
    mockRunner = MockProcessRunner();
    tool = AnalyzeBugHotspotsTool(mockRunner);
  });

  void mockSingleBugChain(MockProcessRunner runner) {
    runner.mockResult(
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

    runner.mockResult(
      'git',
      [
        'log',
        '-1',
        '--format=format:%H%x09%an%x09%ae%x09%aI%x09%s',
        '0123456789abcdef0123456789abcdef01234567',
      ],
      '0123456789abcdef0123456789abcdef01234567\tFixer\tfixer@author.com\t2023-01-02T12:00:00Z\tfix: fixed a critical bug\n',
    );

    runner.mockResult(
        'git',
        [
          'rev-parse',
          '0123456789abcdef0123456789abcdef01234567^',
        ],
        '1111222233334444555566667777888899990000\n');

    runner.mockResult(
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

    runner.mockResult(
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

    runner.mockResult(
      'git',
      [
        'log',
        '-1',
        '--format=format:%H%x09%an%x09%ae%x09%aI%x09%s',
        'fedcba9876543210fedcba9876543210fedcba98',
      ],
      'fedcba9876543210fedcba9876543210fedcba98\tTarget Author\ttarget@author.com\t2023-01-01T12:00:00Z\tfeat: introduced bug\n',
    );
  }

  group('AnalyzeBugHotspotsTool', () {
    test('has correct name and description', () {
      expect(tool.name, 'analyze_bug_hotspots');
      expect(tool.description, isNotEmpty);
    });

    test('has correct schema', () {
      final schema = tool.inputSchema;
      expect((schema['required'] as List).contains('directory'), isTrue);
      expect(schema['properties'], contains('author'));
      expect(schema['properties'], contains('positiveRegex'));
      expect(schema['properties'], contains('negativeRegex'));
    });

    test('returns error for malformed positiveRegex', () async {
      final result = await tool.execute({
        'directory': '.',
        'positiveRegex': '(unclosed',
      });
      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['error'], contains('positiveRegex'));
    });

    test('returns error for malformed negativeRegex', () async {
      final result = await tool.execute({
        'directory': '.',
        'negativeRegex': '[invalid',
      });
      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['error'], contains('negativeRegex'));
    });

    test('aggregates hotspots without an author filter', () async {
      mockSingleBugChain(mockRunner);

      final resultJson = await tool.execute({'directory': './test_dir'});
      final result = jsonDecode(resultJson) as Map<String, dynamic>;

      expect(result['total_fix_commits_analyzed'], 1);
      expect(result.containsKey('developer_bug_analysis'), isFalse);

      final files = result['top_bug_hotspot_files'] as List;
      expect(files.single['file'], 'test_file.dart');

      final authors = result['top_bug_hotspot_authors'] as List;
      expect(authors.single['author'], 'Target Author');
    });

    test('adds developer_bug_analysis when author is supplied', () async {
      mockSingleBugChain(mockRunner);

      final resultJson = await tool.execute({
        'directory': './test_dir',
        'author': 'Target Author',
      });
      final result = jsonDecode(resultJson) as Map<String, dynamic>;

      // Aggregate section is still present and unaffected.
      expect(result['total_fix_commits_analyzed'], 1);

      final developerAnalysis =
          result['developer_bug_analysis'] as Map<String, dynamic>;
      expect(developerAnalysis['author_analyzed'], 'Target Author');
      expect(developerAnalysis['bugs_introduced_count'], 1);

      final bugs = developerAnalysis['bug_introductions'] as List;
      expect(bugs.length, 1);

      final bug = bugs[0] as Map<String, dynamic>;
      expect(
        bug['introducing_commit'],
        'fedcba9876543210fedcba9876543210fedcba98',
      );
      expect(bug['fixing_commit'], '0123456789abcdef0123456789abcdef01234567');
      // Introduced 2023-01-01T12:00Z, fixed 2023-01-02T12:00Z: the SZZ bug
      // lifetime is exactly one day. Reporting days (not hours) is the
      // contract that keeps LLM report narration from misreading the span
      // as fix effort.
      expect(bug['bug_lifetime_in_days'], 1.0);
    });

    test('developer_bug_analysis is empty for a non-matching author', () async {
      mockSingleBugChain(mockRunner);

      final resultJson = await tool.execute({
        'directory': './test_dir',
        'author': 'Someone Else',
      });
      final result = jsonDecode(resultJson) as Map<String, dynamic>;

      final developerAnalysis =
          result['developer_bug_analysis'] as Map<String, dynamic>;
      expect(developerAnalysis['bugs_introduced_count'], 0);
    });
  });
}
