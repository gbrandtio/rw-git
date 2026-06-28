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
      mock.setMockResult('git', ['shortlog', 'HEAD', '-s'], 0,
          '    10\tJohnDoe\n     5\tJaneDoe', '');
      runner = mock;
      rwGit = RwGit(runner: runner);
      tool = GetContributionsByAuthorTool(rwGit);
    });

    test('execute returns contributions', () async {
      final result = await tool.execute({
        'localCheckoutDirectory': 'test_dir',
      });
      final json = jsonDecode(result) as Map<String, dynamic>;
      final contributions = json['contributions'] as List;
      expect(contributions.length, 2);
      expect(contributions[0]['authorName'], 'JohnDoe');
      expect(contributions[0]['numberOfContributions'], 10);
    });

    test('has correct properties', () {
      expect(tool.name, isNotEmpty);
      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema, isNotEmpty);
    });
  });
}
