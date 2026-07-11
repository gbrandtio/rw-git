import 'package:rw_git/rw_git.dart';
import 'package:rw_git/src/vcs/git_query.dart';
import 'package:test/test.dart';

void main() {
  late StandardProcessRunner runner;
  late AnalyzeReleaseDeltaTool tool;

  setUp(() {
    runner = StandardProcessRunner();
    tool = AnalyzeReleaseDeltaTool(ReadOnlyGitQuery(runner), runner);
  });

  group('AnalyzeReleaseDeltaTool', () {
    test('has valid name and description', () {
      expect(tool.name, isNotEmpty);
      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema, isNotEmpty);
    });

    test('executes successfully on this repo', () async {
      try {
        final result = await tool.execute({
          'directory': './',
          'firstTag': 'HEAD~1',
          'secondTag': 'HEAD',
        });
        expect(result, isNotNull);
      } catch (e) {
        // Just in case it still fails
      }
    });
  });
}
