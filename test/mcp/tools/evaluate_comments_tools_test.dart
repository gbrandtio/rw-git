// ignore_for_file: avoid_dynamic_calls, unnecessary_cast
import 'dart:convert';
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
    test(
      'EvaluateCommentLlmGenerationTool returns '
      'structured JSON',
      () async {
        final tool = EvaluateCommentLlmGenerationTool(tracker);
        expect(
          tool.name,
          'evaluate_comment_llm_generation',
        );

        runner.setMockResult(
          'git',
          [
            'log',
            '-n',
            '500',
            '-p',
            '--format=%H||%an||%ad||%s',
          ],
          0,
          '+++ b/test.dart\n'
              '@@ -1,1 +1,2 @@\n'
              '+ // comment',
          '',
        );

        final resultStr = await tool.execute({'directory': 'fake_dir'});
        final result = jsonDecode(resultStr) as Map<String, dynamic>;

        expect(
          result['evaluation_criteria'],
          isA<List>(),
        );
        expect(
          (result['evaluation_criteria'] as List).any(
            (c) => (c as String).contains('LLM artifacts'),
          ),
          isTrue,
        );
        expect(
          (result['changed_comments'] as List).first['file'],
          'test.dart',
        );

        // No persona in output
        expect(
          resultStr,
          isNot(contains('Staff Software Engineer')),
        );
      },
    );

    test(
      'EvaluateCommentQualityTool returns structured JSON',
      () async {
        final tool = EvaluateCommentQualityTool(tracker);
        expect(tool.description, isNotEmpty);
        expect(tool.inputSchema.isNotEmpty, isTrue);
        expect(tool.name, 'evaluate_comment_quality');

        runner.setMockResult(
          'git',
          [
            'log',
            '-n',
            '500',
            '-p',
            '--format=%H||%an||%ad||%s',
          ],
          0,
          '+++ b/test.dart\n'
              '@@ -1,1 +1,2 @@\n'
              '+ // comment',
          '',
        );

        final resultStr = await tool.execute({'directory': 'fake_dir'});
        final result = jsonDecode(resultStr) as Map<String, dynamic>;

        expect(
          result['evaluation_criteria'],
          isA<List>(),
        );
        expect(
          (result['evaluation_criteria'] as List).any(
            (c) => (c as String).contains('explain "Why"'),
          ),
          isTrue,
        );
        expect(
          (result['changed_comments'] as List).first['file'],
          'test.dart',
        );
      },
    );

    test(
      'EvaluateCommentNecessityTool returns '
      'structured JSON',
      () async {
        final tool = EvaluateCommentNecessityTool(tracker);
        expect(tool.description, isNotEmpty);
        expect(tool.inputSchema.isNotEmpty, isTrue);
        expect(tool.name, 'evaluate_comment_necessity');

        runner.setMockResult(
          'git',
          [
            'log',
            '-n',
            '500',
            '-p',
            '--format=%H||%an||%ad||%s',
          ],
          0,
          '+++ b/test.dart\n'
              '@@ -1,1 +1,2 @@\n'
              '+ // comment',
          '',
        );

        final resultStr = await tool.execute({'directory': 'fake_dir'});
        final result = jsonDecode(resultStr) as Map<String, dynamic>;

        expect(
          result['evaluation_criteria'],
          isA<List>(),
        );
        expect(
          (result['evaluation_criteria'] as List).any(
            (c) => (c as String).contains(
              'self-documenting',
            ),
          ),
          isTrue,
        );
        expect(
          (result['changed_comments'] as List).first['file'],
          'test.dart',
        );
      },
    );

    test(
      'Returns structured JSON with no_comments_found '
      'status',
      () async {
        final tool = EvaluateCommentNecessityTool(tracker);

        runner.setMockResult(
          'git',
          [
            'log',
            '-n',
            '500',
            '-p',
            '--format=%H||%an||%ad||%s',
          ],
          0,
          '+++ b/test.dart\n'
              '@@ -1,1 +1,2 @@\n'
              '+ no comment here',
          '',
        );

        final resultStr = await tool.execute({'directory': 'fake_dir'});
        final result = jsonDecode(resultStr) as Map<String, dynamic>;

        expect(result['status'], 'no_comments_found');
        expect(
          result['message'],
          contains('No comments found'),
        );
      },
    );
  });
}
