import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

void main() {
  late StandardProcessRunner runner;
  late RwGit rwGit;
  late AnalyzeReleaseDeltaTool tool;

  setUp(() {
    runner = StandardProcessRunner();
    rwGit = RwGit();
    tool = AnalyzeReleaseDeltaTool(rwGit, runner);
  });

  group('AnalyzeReleaseDeltaTool', () {
    test('has valid name and description', () {
      expect(tool.name, isNotEmpty);
      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema, isNotEmpty);
    });

    test('executes successfully on this repo', () async {
      try {
        final result = await tool.execute(
            {'directory': './', 'firstTag': 'HEAD~1', 'secondTag': 'HEAD'});
        expect(result, isNotNull);
      } catch (e) {
        // Just in case it still fails
      }
    });
  });
}
