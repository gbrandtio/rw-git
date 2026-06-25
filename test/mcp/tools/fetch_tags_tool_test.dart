import 'dart:convert';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

void main() {
  group('FetchTagsTool', () {
    late ProcessRunner runner;
    late RwGit rwGit;
    late FetchTagsTool tool;

    setUp(() {
      final mock = ProcessRunner.mock() as MockProcessRunner;
      mock.setMockResult('git', ['tag', '-l'], 0, 'v1.0.0\nv2.0.0', '');
      runner = mock;
      rwGit = RwGit(runner: runner);
      tool = FetchTagsTool(rwGit);
    });

    test('execute returns tags', () async {
      final result = await tool.execute({
        'localCheckoutDirectory': 'test_dir',
      });
      final json = jsonDecode(result);
      expect((json['tags'] as List).length, 2);
    });
  });
}
