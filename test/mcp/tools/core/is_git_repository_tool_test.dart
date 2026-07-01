// ignore_for_file: avoid_dynamic_calls, unnecessary_cast
import 'dart:convert';
import 'package:rw_git/rw_git.dart';
import 'package:rw_git/src/vcs/git_query.dart';
import 'package:test/test.dart';

void main() {
  group('IsGitRepositoryTool', () {
    late ProcessRunner runner;
    late RwGit rwGit;
    late IsGitRepositoryTool tool;

    setUp(() {
      final mock = ProcessRunner.mock() as MockProcessRunner;
      mock.setMockResult(
          'git', ['rev-parse', '--is-inside-work-tree'], 0, 'true', '');
      runner = mock;
      rwGit = RwGit(runner: runner);
      tool = IsGitRepositoryTool(rwGit, ReadOnlyGitQuery(runner));
    });

    test('execute returns isGitRepository', () async {
      final result = await tool.execute({'directory': 'test_dir'});
      final json = jsonDecode(result) as Map<String, dynamic>;
      expect(json['isGitRepository'], isTrue);
    });

    test('has correct properties', () {
      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema.isNotEmpty, isTrue);
      expect(tool.name, isNotEmpty);
      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema, isNotEmpty);
    });

    test('execute returns false on failure', () async {
      final mock = ProcessRunner.mock() as MockProcessRunner;
      mock.setMockResult('git', ['rev-parse', '--is-inside-work-tree'], 1, '',
          'fatal: not a git repository');
      final rwGit2 = RwGit(runner: mock);
      final tool2 = IsGitRepositoryTool(rwGit2, ReadOnlyGitQuery(mock));
      final result = await tool2.execute({'directory': 'test_dir'});
      final json = jsonDecode(result) as Map<String, dynamic>;
      expect(json['isGitRepository'], isFalse);
    });
  });
}
