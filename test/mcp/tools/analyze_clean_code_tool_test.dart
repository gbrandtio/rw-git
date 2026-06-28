// ignore_for_file: avoid_dynamic_calls
import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:rw_git/src/mcp/tools/analyze_clean_code_tool.dart';

void main() {
  group('AnalyzeCleanCodeTool', () {
    test('has correct name and schema', () {
      final tool = AnalyzeCleanCodeTool();
      expect(tool.name, 'analyze_clean_code');
      expect(tool.description, isNotEmpty);
    });

    test('analyzes clean code heuristics', () async {
      final tempDir = Directory.systemTemp.createTempSync('clean_code_test');
      final file = File('${tempDir.path}/test.dart');

      final content = '''
void main() {
  if (true) {
    if (true) {
      if (true) {
        if (true) {
          if (true) {
            print('Deep nesting');
          }
        }
      }
    }
  }
}
''';
      file.writeAsStringSync(content);

      final tool = AnalyzeCleanCodeTool();
      final result = await tool.execute({
        'file_path': file.path,
      });

      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['total_lines'], 13);
      expect(parsed['max_indentation_level'], 3); // 12 spaces = 3 levels

      tempDir.deleteSync(recursive: true);
    });
  });
}
