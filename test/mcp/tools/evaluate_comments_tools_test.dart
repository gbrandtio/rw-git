// ignore_for_file: avoid_dynamic_calls, unnecessary_cast
import 'package:test/test.dart';
import 'package:rw_git/rw_git.dart';

void main() {
  late MockProcessRunner runner;
  late CodeQualityTracker tracker;

  setUp(() {
    runner = MockProcessRunner();
    tracker = CodeQualityTracker(runner);
  });

  group('EvaluateComment Tools', () {
    test('EvaluateCommentLlmGenerationTool executes and returns prompt',
        () async {
      final tool = EvaluateCommentLlmGenerationTool(tracker);
      expect(tool.name, 'evaluate_comment_llm_generation');

      runner.setMockResult(
          'git',
          ['log', '-n', '10', '-p', '--format=%H||%an||%ad||%s'],
          0,
          '+++ b/test.dart\n@@ -1,1 +1,2 @@\n+ // comment',
          '');

      final result = await tool.execute({'directory': 'fake_dir'});
      expect(result, contains('You are a Staff Software Engineer.'));
      expect(result, contains('exhibit signs of being LLM generated'));
      expect(result, contains('File: test.dart'));
    });

    test('EvaluateCommentQualityTool executes and returns prompt', () async {
      final tool = EvaluateCommentQualityTool(tracker);
      expect(tool.name, 'evaluate_comment_quality');

      runner.setMockResult(
          'git',
          ['log', '-n', '10', '-p', '--format=%H||%an||%ad||%s'],
          0,
          '+++ b/test.dart\n@@ -1,1 +1,2 @@\n+ // comment',
          '');

      final result = await tool.execute({'directory': 'fake_dir'});
      expect(result, contains('You are a Staff Software Engineer.'));
      expect(result, contains('Evaluate the quality of the provided comments'));
      expect(result, contains('File: test.dart'));
    });

    test('EvaluateCommentNecessityTool executes and returns prompt', () async {
      final tool = EvaluateCommentNecessityTool(tracker);
      expect(tool.name, 'evaluate_comment_necessity');

      runner.setMockResult(
          'git',
          ['log', '-n', '10', '-p', '--format=%H||%an||%ad||%s'],
          0,
          '+++ b/test.dart\n@@ -1,1 +1,2 @@\n+ // comment',
          '');

      final result = await tool.execute({'directory': 'fake_dir'});
      expect(result, contains('You are a Staff Software Engineer.'));
      expect(
          result,
          contains(
              'Evaluate whether each of the provided comments is truly necessary'));
      expect(result, contains('File: test.dart'));
    });

    test('Returns empty message if no comments found', () async {
      final tool = EvaluateCommentNecessityTool(tracker);

      runner.setMockResult(
          'git',
          ['log', '-n', '10', '-p', '--format=%H||%an||%ad||%s'],
          0,
          '+++ b/test.dart\n@@ -1,1 +1,2 @@\n+ no comment here',
          '');

      final result = await tool.execute({'directory': 'fake_dir'});
      expect(result, contains('No comments found'));
    });
  });
}
