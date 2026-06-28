// ignore_for_file: avoid_dynamic_calls, unnecessary_cast
import 'dart:convert';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

void main() {
  group('AnalyzeReleaseDeltaTool', () {
    late MockProcessRunner mockRunner;
    late RwGit rwGit;

    setUp(() {
      mockRunner = MockProcessRunner();
      rwGit = RwGit(runner: mockRunner);
    });

    test('has correct name and input schema', () {
      final tool = AnalyzeReleaseDeltaTool(rwGit);
      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema.isNotEmpty, isTrue);
      expect(tool.name, 'analyze_release_delta');
      expect(tool.inputSchema['required'],
          containsAll(['localCheckoutDirectory', 'firstTag', 'secondTag']));
    });

    test('execute aggregates data correctly', () async {
      mockRunner.setMockResult(
        'git',
        ['log', 'v1..v2', '--format=%H||%an||%ad||%s'],
        0,
        'hash1||Alice||date||msg1\nhash2||Bob||date||msg2\nhash3||Alice||date||msg3\n',
        '',
      );

      mockRunner.setMockResult(
        'git',
        ['diff', '--numstat', 'v1', 'v2'],
        0,
        '10\t5\tfile1.dart\n2\t0\tfile2.dart\n',
        '',
      );

      final tool = AnalyzeReleaseDeltaTool(rwGit);
      final resultRaw = await tool.execute({
        'localCheckoutDirectory': '/test/dir',
        'firstTag': 'v1',
        'secondTag': 'v2',
      });

      final result = jsonDecode(resultRaw) as Map<String, dynamic>;

      expect(result['total_commits'], 3);
      expect(result['total_insertions'], 12);
      expect(result['total_deletions'], 5);
      expect(result['files_changed'], 2);
      expect(result['active_contributors'], 2);
      expect((result['top_modified_files'] as List).length, 2);
      expect(result['top_modified_files'][0]['file'], 'file1.dart');
      expect(result['authors_breakdown']['Alice'], 2);
      expect(result['authors_breakdown']['Bob'], 1);
      expect(result.containsKey('commits'), isFalse);
    });

    test('execute includes raw commits when detailed is true', () async {
      mockRunner.setMockResult(
        'git',
        ['log', 'v1..v2', '--format=%H||%an||%ad||%s'],
        0,
        'hash1||Alice||date||msg1\n',
        '',
      );

      mockRunner.setMockResult(
        'git',
        ['diff', '--numstat', 'v1', 'v2'],
        0,
        '',
        '',
      );

      final tool = AnalyzeReleaseDeltaTool(rwGit);
      final resultRaw = await tool.execute({
        'localCheckoutDirectory': '/test/dir',
        'firstTag': 'v1',
        'secondTag': 'v2',
        'detailed': true,
      });

      final result = jsonDecode(resultRaw) as Map<String, dynamic>;
      expect(result.containsKey('commits'), isTrue);
      expect(((result['commits'] as List) as List).first,
          'hash1||Alice||date||msg1');
    });
  });
}
