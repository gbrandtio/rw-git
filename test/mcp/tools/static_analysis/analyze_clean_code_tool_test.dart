import 'dart:convert';
import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

void main() {
  late AnalyzeCleanCodeTool tool;

  setUp(() {
    tool = AnalyzeCleanCodeTool();
  });

  group('AnalyzeCleanCodeTool', () {
    test('has valid name and description', () {
      expect(tool.name, isNotEmpty);
      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema, isNotEmpty);
    });

    test('executes successfully on this repo', () async {
      final result = await tool.execute({'file_path': 'lib/rw_git.dart'});
      expect(result, isNotNull);
    });

    test('returns error when file does not exist', () async {
      final result =
          await tool.execute({'file_path': 'non_existent_file.dart'});
      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['error'], contains('File not found'));
    });

    test('detects long lines, deep nesting, and file length', () async {
      final tempFile = File('test_clean_code.dart');
      final lines = List.generate(350, (i) => 'void main() {}');
      // Add a very long line
      lines[0] = List.generate(150, (i) => 'a').join();
      // Add a deep nested line (tabs and spaces)
      lines[1] = '\t\t\t\t\t          int x = 1;';
      // Add enough long lines to trigger the longLines threshold (35 > 350 * 0.1)
      for (int i = 2; i < 40; i++) {
        lines[i] = List.generate(150, (i) => 'b').join();
      }

      await tempFile.writeAsString(lines.join('\n'));

      final result = await tool.execute({'file_path': 'test_clean_code.dart'});
      final parsed = jsonDecode(result) as Map<String, dynamic>;

      expect(parsed['file'], 'test_clean_code.dart');
      expect(parsed['total_lines'], 350);
      expect(parsed['clean_code_issues'], hasLength(3));
      expect(parsed['risk_level'], 'high');

      await tempFile.delete();
    });

    test('detects medium risk', () async {
      final tempFile = File('test_clean_code_medium.dart');
      final lines = List.generate(350, (i) => 'void main() {}');
      await tempFile.writeAsString(lines.join('\n'));

      final result =
          await tool.execute({'file_path': 'test_clean_code_medium.dart'});
      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['risk_level'], 'medium');
      expect(parsed['clean_code_issues'], hasLength(1));

      await tempFile.delete();
    });
  });
}
