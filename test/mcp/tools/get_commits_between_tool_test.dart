// ignore_for_file: avoid_dynamic_calls, unnecessary_cast
import 'dart:convert';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

void main() {
  group('GetCommitsBetweenTool', () {
    late ProcessRunner runner;
    late RwGit rwGit;
    late GetCommitsBetweenTool tool;

    setUp(() {
      final mock = ProcessRunner.mock() as MockProcessRunner;
      mock.setMockResult(
          'git', ['rev-list', 'v1...v2'], 0, 'commit1\ncommit2', '');
      runner = mock;
      rwGit = RwGit(runner: runner);
      tool = GetCommitsBetweenTool(rwGit);
    });

    test('execute returns commits', () async {
      final result = await tool.execute({
        'localCheckoutDirectory': 'test_dir',
        'firstTag': 'v1',
        'secondTag': 'v2'
      });
      final json = jsonDecode(result) as Map<String, dynamic>;
      expect((json['commits'] as List).length, 2);
    });
  });
}
