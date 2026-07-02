// ignore_for_file: avoid_dynamic_calls, unnecessary_cast
import 'dart:convert';
import 'package:test/test.dart';
import 'package:rw_git/rw_git.dart';

void main() {
  late MockProcessRunner runner;

  const gitArgs = [
    'log',
    '-n',
    '500',
    '-p',
    '--format=%H||%an||%aI||%s',
  ];

  const sampleDiff = '+++ b/test.dart\n'
      '@@ -1,1 +1,2 @@\n'
      '+ // comment';

  setUp(() {
    runner = MockProcessRunner();
  });

  group('EvaluateCommentsTool', () {
    test('name and schema', () {
      final tool = EvaluateCommentsTool(runner);
      expect(tool.name, 'evaluate_comments');
      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema.isNotEmpty, isTrue);
    });

    test('defaults to all aspects with keyed criteria', () async {
      final tool = EvaluateCommentsTool(runner);
      runner.setMockResult('git', gitArgs, 0, sampleDiff, '');

      final result = jsonDecode(await tool.execute({'directory': 'fake_dir'}))
          as Map<String, dynamic>;

      expect(result['aspects'],
          containsAll(['quality', 'necessity', 'llm_generation']));

      final criteria = result['evaluation_criteria'] as Map<String, dynamic>;
      expect(criteria.keys,
          containsAll(['quality', 'necessity', 'llm_generation']));
      expect(
        (criteria['llm_generation'] as List).any(
          (c) => (c as String).contains('LLM artifacts'),
        ),
        isTrue,
      );
      expect(
        (criteria['quality'] as List).any(
          (c) => (c as String).contains('explain "Why"'),
        ),
        isTrue,
      );
      expect(
        (criteria['necessity'] as List).any(
          (c) => (c as String).contains('self-documenting'),
        ),
        isTrue,
      );
      expect((result['changed_comments'] as List).first['file'], 'test.dart');
      expect(result.toString(), isNot(contains('Staff Software Engineer')));
    });

    test('selects only requested aspects', () async {
      final tool = EvaluateCommentsTool(runner);
      runner.setMockResult('git', gitArgs, 0, sampleDiff, '');

      final result = jsonDecode(await tool
              .execute({'directory': 'fake_dir', 'aspects': 'quality'}))
          as Map<String, dynamic>;

      expect(result['aspects'], ['quality']);
      final criteria = result['evaluation_criteria'] as Map<String, dynamic>;
      expect(criteria.keys, ['quality']);
    });

    test('unknown aspects fall back to all', () async {
      final tool = EvaluateCommentsTool(runner);
      runner.setMockResult('git', gitArgs, 0, sampleDiff, '');

      final result = jsonDecode(
              await tool.execute({'directory': 'fake_dir', 'aspects': 'bogus'}))
          as Map<String, dynamic>;

      expect((result['aspects'] as List).length, 3);
    });

    test('returns no_comments_found status', () async {
      final tool = EvaluateCommentsTool(runner);
      runner.setMockResult(
        'git',
        gitArgs,
        0,
        '+++ b/test.dart\n'
            '@@ -1,1 +1,2 @@\n'
            '+ no comment here',
        '',
      );

      final result = jsonDecode(await tool.execute({'directory': 'fake_dir'}))
          as Map<String, dynamic>;

      expect(result['status'], 'no_comments_found');
      expect(result['message'], contains('No comments found'));
    });
  });
}
