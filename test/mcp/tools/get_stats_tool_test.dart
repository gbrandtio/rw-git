// ignore_for_file: avoid_dynamic_calls, unnecessary_cast
import 'dart:convert';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

void main() {
  group('GetStatsTool', () {
    late ProcessRunner runner;
    late RwGit rwGit;
    late GetStatsTool tool;

    setUp(() {
      final mock = ProcessRunner.mock() as MockProcessRunner;
      mock.setMockResult('git', ['diff', '--shortstat', 'v1', 'v2'], 0,
          ' 3 files changed, 50 insertions(+), 10 deletions(-)', '');
      mock.setMockResult('git', ['diff', '--numstat', 'v1', 'v2'], 0,
          '10\t2\tfile1.dart\n40\t8\tfile2.dart', '');
      runner = mock;
      rwGit = RwGit(runner: runner);
      tool = GetStatsTool(rwGit);
    });

    test('execute returns stats', () async {
      final result = await tool
          .execute({'directory': 'test_dir', 'oldTag': 'v1', 'newTag': 'v2'});
      final json = jsonDecode(result) as Map<String, dynamic>;
      expect(json['numberOfChangedFiles'], 3);
      expect(json['insertions'], 50);
      expect(json['deletions'], 10);
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
