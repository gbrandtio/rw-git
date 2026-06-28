import 'package:test/test.dart';
import 'package:rw_git/src/mcp/tools/analyze_architecture_drift_tool.dart';
import 'package:rw_git/rw_git.dart';

void main() {
  test('AnalyzeArchitectureDriftTool properties', () async {
    final tool = AnalyzeArchitectureDriftTool(RwGit());
    expect(tool.name, 'analyze_architecture_drift');
    expect(tool.description, isNotEmpty);
    expect(tool.inputSchema, isNotEmpty);
    
    final res = await tool.execute({'directory': '.', 'layer_patterns': <String, dynamic>{}});
    expect(res, isNotNull);
  });
}
