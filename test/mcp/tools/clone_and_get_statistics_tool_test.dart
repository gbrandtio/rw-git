import 'dart:convert';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

void main() {
  group('CloneAndGetStatisticsTool', () {
    late ProcessRunner runner;
    late RwGit rwGit;
    late CloneAndGetStatisticsTool tool;

    setUp(() {
      final mock = ProcessRunner.mock() as MockProcessRunner;
      mock.setMockResult('git', ['clone', '--', 'https://github.com/repo'], 0,
          'Cloning...', '');
      mock.setMockResult('git', ['diff', '--shortstat', 'v1', 'v2'], 0,
          ' 3 files changed, 50 insertions(+), 10 deletions(-)', '');
      runner = mock;
      rwGit = RwGit(runner: runner);
      tool = CloneAndGetStatisticsTool(rwGit);
    });

    test('execute returns stats', () async {
      final result = await tool.execute({
        'localDirectoryToCloneInto': 'test_dir',
        'repository': 'https://github.com/repo',
        'oldTag': 'v1',
        'newTag': 'v2'
      });
      final json = jsonDecode(result);
      expect(json['numberOfChangedFiles'], 3);
      expect(json['insertions'], 50);
      expect(json['deletions'], 10);
    });
  });
}
