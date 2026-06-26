// ignore_for_file: avoid_dynamic_calls, unnecessary_cast
import 'dart:convert';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

void main() {
  group('CloneRepositoryTool', () {
    late ProcessRunner runner;
    late RwGit rwGit;
    late CloneRepositoryTool tool;

    setUp(() {
      final mock = ProcessRunner.mock() as MockProcessRunner;
      mock.setMockResult('git', ['clone', '--', 'https://github.com/repo'], 0,
          'Cloning...', '');
      runner = mock;
      rwGit = RwGit(runner: runner);
      tool = CloneRepositoryTool(rwGit);
    });

    test('execute returns success', () async {
      final result = await tool.execute({
        'localDirectoryToCloneInto': 'test_dir',
        'repository': 'https://github.com/repo'
      });
      final json = jsonDecode(result) as Map<String, dynamic>;
      expect(json['success'], isTrue);
    });
  });
}
