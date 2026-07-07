// ignore_for_file: avoid_dynamic_calls, unnecessary_cast
import 'dart:convert';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

void main() {
  group('GetContributionsByAuthorTool', () {
    late ProcessRunner runner;
    late RwGit rwGit;
    late GetContributionsByAuthorTool tool;

    setUp(() {
      final mock = ProcessRunner.mock() as MockProcessRunner;
      mock.setMockResult('git', ['shortlog', 'HEAD', '-s', '-n', '--no-merges'],
          0, '    10\tJohnDoe\n     5\tJaneDoe', '');
      mock.setMockResult(
          'git',
          [
            'shortlog',
            'HEAD',
            '-s',
            '-n',
            '--no-merges',
            '--since=2024-01-01',
            '--until=2024-12-31',
          ],
          0,
          '    3\tJohnDoe',
          '');
      runner = mock;
      rwGit = RwGit(runner: runner);
      tool = GetContributionsByAuthorTool(rwGit);
    });

    test('execute returns contributions', () async {
      final result = await tool.execute({
        'directory': 'test_dir',
      });
      final json = jsonDecode(result) as Map<String, dynamic>;
      final contributions = json['contributions'] as List;
      expect(contributions.length, 2);
      expect(contributions[0]['authorName'], 'JohnDoe');
      expect(contributions[0]['numberOfContributions'], 10);
    });

    test('execute forwards since/until as git flags', () async {
      final result = await tool.execute({
        'directory': 'test_dir',
        'since': '2024-01-01',
        'until': '2024-12-31',
      });
      final json = jsonDecode(result) as Map<String, dynamic>;
      final contributions = json['contributions'] as List;
      expect(contributions.length, 1);
      expect(contributions[0]['numberOfContributions'], 3);
    });

    test('execute rejects an invalid since value', () async {
      final result = await tool.execute({
        'directory': 'test_dir',
        'since': 'not-a-date',
      });
      final json = jsonDecode(result) as Map<String, dynamic>;
      expect(json['error'], contains('Invalid "since"'));
    });

    test('execute rejects an invalid until value', () async {
      final result = await tool.execute({
        'directory': 'test_dir',
        'until': 'not-a-date',
      });
      final json = jsonDecode(result) as Map<String, dynamic>;
      expect(json['error'], contains('Invalid "until"'));
    });

    test('has correct properties', () {
      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema.isNotEmpty, isTrue);
      expect(tool.name, isNotEmpty);
      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema, isNotEmpty);
    });

    test('exposes since/until in schema', () {
      final props = tool.inputSchema['properties'] as Map<String, dynamic>;
      expect(props.containsKey('since'), isTrue);
      expect(props.containsKey('until'), isTrue);
    });
  });
}
