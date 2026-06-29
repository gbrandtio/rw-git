// ignore_for_file: avoid_dynamic_calls, unnecessary_cast
import 'dart:convert';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

void main() {
  group('InitRepositoryTool', () {
    late ProcessRunner runner;
    late RwGit rwGit;
    late InitRepositoryTool tool;

    setUp(() {
      final mock = ProcessRunner.mock() as MockProcessRunner;
      mock.setMockResult(
          'git', ['init'], 0, 'Initialized empty Git repository', '');
      runner = mock;
      rwGit = RwGit(runner: runner);
      tool = InitRepositoryTool(rwGit);
    });

    test('execute returns success', () async {
      final result = await tool.execute({'directory': 'test_dir'});
      final json = jsonDecode(result) as Map<String, dynamic>;
      expect(json['success'], isTrue);
    });

    test('has correct properties', () {
      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema.isNotEmpty, isTrue);
      expect(tool.name, isNotEmpty);
      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema, isNotEmpty);
    });
  });
}
