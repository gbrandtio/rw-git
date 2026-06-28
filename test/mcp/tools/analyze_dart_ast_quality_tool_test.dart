import 'package:test/test.dart';
import 'package:rw_git/rw_git.dart';

void main() {
  test('AnalyzeDartAstQualityTool properties and error handling', () async {
    final tool = AnalyzeDartAstQualityTool(RwGit());
    expect(tool.name, 'analyze_dart_ast_quality');
    expect(tool.description, isNotEmpty);
    expect(tool.inputSchema, isNotEmpty);

    final res = await tool.execute(
        {'directory': '.', 'baseBranch': 'HEAD~1', 'targetBranch': 'HEAD'});
    expect(res, isNotNull);
  });
}
