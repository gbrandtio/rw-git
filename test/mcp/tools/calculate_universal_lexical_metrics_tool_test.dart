import 'package:test/test.dart';
import 'package:rw_git/src/mcp/tools/calculate_universal_lexical_metrics_tool.dart';

void main() {
  test('calculate', () async {
    final tool = CalculateUniversalLexicalMetricsTool();
    final result = await tool.execute({'file_path': 'test.dart'});
    expect(result, isNotNull);
    expect(result, contains('cyclomatic_complexity'));
  });
}
