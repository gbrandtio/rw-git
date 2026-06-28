import 'package:test/test.dart';
import 'package:rw_git/src/mcp/tools/analyze_clean_code_tool.dart';
import 'package:rw_git/rw_git.dart';

void main() {
  test('AnalyzeCleanCodeTool properties', () async {
    final tool = AnalyzeCleanCodeTool();
    expect(tool.name, 'analyze_clean_code');
    expect(tool.description, isNotEmpty);
    expect(tool.inputSchema, isNotEmpty);

    final res = await tool.execute({'file_path': 'nonexistent_repo'});
    expect(res, isNotNull);
  });
}
