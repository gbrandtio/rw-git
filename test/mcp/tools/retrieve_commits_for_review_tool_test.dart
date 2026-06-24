import 'package:rw_git/rw_git.dart';

import 'package:test/test.dart';

void main() {
  group('RetrieveCommitsForReviewTool', () {
    late ProcessRunner runner;
    late RwGit rwGit;
    late RetrieveCommitsForReviewTool tool;

    setUp(() {
      final mock = ProcessRunner.mock() as MockProcessRunner;
      mock.setMockResult('git', ['log', '-n', '10', '-p'], 0,
          'commit 123\nAuthor: test\n\n    fixme', '');
      mock.setMockResult('git', ['log', '-n', '5', '-p'], 0,
          'commit 123\nAuthor: test\n\n    fixme', '');
      runner = mock;
      rwGit = RwGit(runner: runner);
      tool = RetrieveCommitsForReviewTool(rwGit);
    });

    test('has correct name and input schema', () {
      expect(tool.name, 'retrieve_commits_for_ai_review');
      expect(tool.description,
          contains('Retrieves recent commits with a structured prompt'));
      expect(tool.inputSchema['type'], 'object');
      expect(
          (tool.inputSchema['required'] as List).contains('directory'), isTrue);
    });

    test(
        'execute executes git log and returns formatted prompt with default limit',
        () async {
      final result = await tool.execute({
        'directory': '/test/dir',
      });

      expect(result, contains('You are an expert AI code reviewer.'));
      expect(result, contains('commit 123'));
      expect(result, contains('fixme'));
    });

    test('execute passes limit correctly when specified', () async {
      final result = await tool.execute({
        'directory': '/test/dir',
        'limit': 5,
      });

      expect(result, contains('commit 123'));
    });
  });
}
