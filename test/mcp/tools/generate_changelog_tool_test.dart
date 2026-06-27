// ignore_for_file: avoid_dynamic_calls
import 'dart:convert';
import 'package:rw_git/rw_git.dart';
import 'package:rw_git/src/core/result.dart';
import 'package:rw_git/src/mcp/tools/generate_changelog_tool.dart';
import 'package:test/test.dart';

class _MockRwGit implements RwGit {
  final String logOutput;

  _MockRwGit(this.logOutput);

  @override
  String get invalidGitCommandResult => 'INVALID';
  @override
  String get gitRepoIndicator => '.git';

  @override
  Future<Result<String, RwGitException>> runCommand(
    String directory,
    List<String> args, {
    bool streamOutput = false,
  }) async {
    return Success(logOutput);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  group('GenerateChangelogTool', () {
    test('has correct name and schema', () {
      final tool = GenerateChangelogTool(_MockRwGit(''));

      expect(tool.name, 'generate_changelog');
      expect(tool.inputSchema['required'],
          containsAll(['directory', 'from', 'to']));
    });

    test('groups conventional commits correctly', () async {
      final log = [
        'aaa||Alice||feat: add login page',
        'bbb||Bob||fix: resolve crash on startup',
        'ccc||Alice||chore: update dependencies',
        'ddd||Carol||feat(auth)!: BREAKING CHANGE redesign API',
      ].join('\n');

      final tool = GenerateChangelogTool(_MockRwGit(log));

      final result = await tool.execute({
        'directory': '/test',
        'from': 'v1.0.0',
        'to': 'v2.0.0',
      });

      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['total_commits'], 4);
      expect((parsed['features'] as List).length, 1);
      expect((parsed['fixes'] as List).length, 1);
      expect((parsed['breaking_changes'] as List).length, 1);
      expect((parsed['other'] as List).length, 1);
      expect(
        parsed['contributors'],
        containsAll(['Alice', 'Bob', 'Carol']),
      );
    });

    test('handles non-conventional commits', () async {
      final log = [
        'aaa||Alice||Updated the readme',
        'bbb||Bob||Fixed a bug',
      ].join('\n');

      final tool = GenerateChangelogTool(_MockRwGit(log));

      final result = await tool.execute({
        'directory': '/test',
        'from': 'v1.0.0',
        'to': 'v2.0.0',
      });

      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['total_commits'], 2);
      expect((parsed['other'] as List).length, 2);
      expect((parsed['features'] as List).length, 0);
    });

    test('handles empty log', () async {
      final tool = GenerateChangelogTool(_MockRwGit(''));

      final result = await tool.execute({
        'directory': '/test',
        'from': 'v1.0.0',
        'to': 'v2.0.0',
      });

      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['total_commits'], 0);
    });
  });
}
