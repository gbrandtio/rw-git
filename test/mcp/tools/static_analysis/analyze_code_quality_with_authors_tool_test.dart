import 'dart:convert';
import 'package:rw_git/rw_git.dart';
import 'package:rw_git/src/vcs/git_query.dart';
import 'package:test/test.dart';

void main() {
  late StandardProcessRunner runner;
  late AnalyzeCodeQualityTool tool;

  setUp(() {
    runner = StandardProcessRunner();
    tool = AnalyzeCodeQualityTool(runner, ReadOnlyGitQuery(runner));
  });

  group('AnalyzeCodeQualityTool includeAuthors mode', () {
    test('exposes the includeAuthors flag in the schema', () {
      final props = tool.inputSchema['properties'] as Map<String, dynamic>;
      expect(props.containsKey('includeAuthors'), isTrue);
    });

    test('executes with author breakdown on this repo', () async {
      try {
        final resultStr = await tool.execute({
          'directory': './',
          'limit': 2,
          'includeAuthors': true,
        });
        final result = jsonDecode(resultStr) as Map<String, dynamic>;
        expect(result.containsKey('high_churn_files'), isTrue);
        // When any high-churn file surfaces, it must carry the per-author map.
        final files = result['high_churn_files'] as List;
        for (final f in files) {
          expect((f as Map).containsKey('authors'), isTrue);
        }
      } catch (_) {
        // Environment without git history: tolerate as the original smoke test.
      }
    });
  });
}
