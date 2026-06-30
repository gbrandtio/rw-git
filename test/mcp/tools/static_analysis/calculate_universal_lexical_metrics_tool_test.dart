import 'dart:convert';
import 'dart:io';
import 'package:rw_git/src/mcp/tools/static_analysis/calculate_universal_lexical_metrics_tool.dart';
import 'package:test/test.dart';

void main() {
  late CalculateUniversalLexicalMetricsTool tool;

  setUp(() {
    tool = CalculateUniversalLexicalMetricsTool();
  });

  group('CalculateUniversalLexicalMetricsTool', () {
    test('has valid name, description, and schema', () {
      expect(tool.name, 'calculate_universal_lexical_metrics');
      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema['required'],
          containsAll(['directory', 'file_path']));
    });

    test('rejects path traversal outside directory', () async {
      final result = await tool.execute({
        'directory': '.',
        'file_path': '../../etc/passwd',
      });
      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['error'], contains('must resolve within directory'));
    });

    test('returns error when file does not exist', () async {
      final tempDir =
          Directory.systemTemp.createTempSync('lexical_metrics_test_');
      final result = await tool.execute({
        'directory': tempDir.path,
        'file_path': 'no_such_file.dart',
      });
      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['error'], contains('File not found'));
      await tempDir.delete(recursive: true);
    });

    test('returns metrics for a valid Dart file', () async {
      final tempDir =
          Directory.systemTemp.createTempSync('lexical_metrics_test_');
      final srcFile = File('${tempDir.path}/sample.dart');
      await srcFile.writeAsString('''
void main() {
  for (int i = 0; i < 10; i++) {
    if (i % 2 == 0) {
      print(i);
    }
  }
}
''');

      final result = await tool.execute({
        'directory': tempDir.path,
        'file_path': 'sample.dart',
      });
      final parsed = jsonDecode(result) as Map<String, dynamic>;

      expect(parsed.containsKey('cyclomatic_complexity'), isTrue);
      expect(parsed.containsKey('halstead_metrics'), isTrue);
      expect(parsed.containsKey('maintainability_index'), isTrue);

      await tempDir.delete(recursive: true);
    });

    test('accepts absolute file_path within directory', () async {
      final tempDir =
          Directory.systemTemp.createTempSync('lexical_metrics_test_');
      final srcFile = File('${tempDir.path}/abs.dart');
      await srcFile.writeAsString('void main() {}');

      final result = await tool.execute({
        'directory': tempDir.path,
        'file_path': srcFile.path,
      });
      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed.containsKey('error'), isFalse);

      await tempDir.delete(recursive: true);
    });
  });
}
