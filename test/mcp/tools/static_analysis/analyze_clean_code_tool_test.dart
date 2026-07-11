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
      final result = await tool.execute({
        'directory': '.',
        'file_path': 'lib/rw_git.dart',
      });
      expect(result, isNotNull);
    });

    test('returns error when file does not exist', () async {
      final result = await tool.execute({
        'directory': '.',
        'file_path': 'non_existent_file.dart',
      });
      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['error'], contains('File not found'));
    });

    test('rejects path traversal outside directory', () async {
      final result = await tool.execute({
        'directory': '.',
        'file_path': '../../etc/passwd',
      });
      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['error'], contains('must resolve within directory'));
    });

    test('detects long lines, deep nesting, and file length', () async {
      final tempDir = Directory.systemTemp.createTempSync('clean_code_test_');
      final tempFile = File('${tempDir.path}/test_clean_code.dart');
      // Unique lines so the duplicate-line heuristic stays silent and the
      // test isolates length, nesting, and long-line detection.
      final lines = List.generate(350, (i) => 'void uniqueMethod$i() {}');
      // Add a very long line
      lines[0] = List.generate(150, (i) => 'a').join();
      // Add a deep nested line (tabs and spaces)
      lines[1] = '\t\t\t\t\t          int x = 1;';
      // Add enough long lines to trigger the longLines threshold (35 > 350 * 0.1)
      for (int i = 2; i < 40; i++) {
        lines[i] = 'x$i = "${List.generate(150, (i) => 'b').join()}";';
      }

      await tempFile.writeAsString(lines.join('\n'));

      final result = await tool.execute({
        'directory': tempDir.path,
        'file_path': 'test_clean_code.dart',
      });
      final parsed = jsonDecode(result) as Map<String, dynamic>;

      expect(parsed['total_lines'], 350);
      expect(parsed['clean_code_issues'], hasLength(3));
      expect(parsed['risk_level'], 'high');

      await tempDir.delete(recursive: true);
    });

    test('detects medium risk', () async {
      final tempDir = Directory.systemTemp.createTempSync('clean_code_test_');
      final tempFile = File('${tempDir.path}/test_clean_code_medium.dart');
      // Unique lines: only the file-length heuristic should fire.
      final lines = List.generate(350, (i) => 'void uniqueMethod$i() {}');
      await tempFile.writeAsString(lines.join('\n'));

      final result = await tool.execute({
        'directory': tempDir.path,
        'file_path': 'test_clean_code_medium.dart',
      });
      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['risk_level'], 'medium');
      expect(parsed['clean_code_issues'], hasLength(1));

      await tempDir.delete(recursive: true);
    });

    test('returns magic_numbers and duplicate_lines fields', () async {
      final tempDir = Directory.systemTemp.createTempSync('clean_code_test_');
      final tempFile = File('${tempDir.path}/magic.dart');
      await tempFile.writeAsString('''
void compute() {
  int result = 42 * 100 + 256;
  int other = 1024 / 8;
  int x = 2 + 3;
}
''');

      final result = await tool.execute({
        'directory': tempDir.path,
        'file_path': 'magic.dart',
      });
      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed.containsKey('magic_numbers'), isTrue);
      expect(parsed.containsKey('duplicate_lines'), isTrue);
      expect(parsed['magic_numbers'], isA<int>());
      expect(parsed['duplicate_lines'], isA<int>());

      await tempDir.delete(recursive: true);
    });

    test('detects duplicate lines', () async {
      final tempDir = Directory.systemTemp.createTempSync('clean_code_test_');
      final tempFile = File('${tempDir.path}/dup.dart');
      // 5 identical lines → 4 duplicates
      await tempFile.writeAsString(
        List.filled(5, 'print("hello world");').join('\n'),
      );

      final result = await tool.execute({
        'directory': tempDir.path,
        'file_path': 'dup.dart',
      });
      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['duplicate_lines'], greaterThan(0));

      await tempDir.delete(recursive: true);
    });

    test('flags magic numbers issue when count exceeds threshold', () async {
      final tempDir = Directory.systemTemp.createTempSync('clean_code_test_');
      final tempFile = File('${tempDir.path}/many_magic.dart');
      // Generate 15 distinct magic numbers in arithmetic context
      final nums = List.generate(15, (i) => 'int v$i = ${i + 2} * 42;');
      await tempFile.writeAsString(nums.join('\n'));

      final result = await tool.execute({
        'directory': tempDir.path,
        'file_path': 'many_magic.dart',
      });
      final parsed = jsonDecode(result) as Map<String, dynamic>;
      final issues = parsed['clean_code_issues'] as List;
      expect(issues.any((i) => (i as String).contains('magic number')), isTrue);

      await tempDir.delete(recursive: true);
    });
  });
}
