import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:rw_git/src/mcp/tools/system/read_report_slice_tool.dart';

void main() {
  late Directory tempDir;
  late Directory reportsDir;
  late ReadReportSliceTool tool;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('read_report_slice_test_');
    reportsDir = Directory(p.join(tempDir.path, '.rw_git', 'reports'));
    await reportsDir.create(recursive: true);
    tool = ReadReportSliceTool();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<String> writeReport(Map<String, dynamic> data) async {
    final file = File(p.join(reportsDir.path, 'mock_report.json'));
    await file.writeAsString(jsonEncode(data));
    return file.path;
  }

  group('ReadReportSliceTool', () {
    test('returns the whole root value when no path is provided', () async {
      final file = await writeReport({'a': 1, 'b': 2});

      final resultString = await tool.execute({'file': file});
      final result = jsonDecode(resultString) as Map<String, dynamic>;

      expect(result['data'], equals({'a': 1, 'b': 2}));
    });

    test('resolves a nested dot-separated path', () async {
      final file = await writeReport({
        'summary': {'totals': 42}
      });

      final resultString =
          await tool.execute({'file': file, 'path': 'summary.totals'});
      final result = jsonDecode(resultString) as Map<String, dynamic>;

      expect(result['data'], equals(42));
    });

    test('slices an array with default offset/limit', () async {
      final file =
          await writeReport({'findings': List.generate(120, (i) => i)});

      final resultString =
          await tool.execute({'file': file, 'path': 'findings'});
      final result = jsonDecode(resultString) as Map<String, dynamic>;

      expect(result['total_length'], equals(120));
      expect(result['offset'], equals(0));
      expect(result['limit'], equals(50));
      expect((result['data'] as List).length, equals(50));
      expect((result['data'] as List).first, equals(0));
    });

    test('slices an array with explicit offset/limit', () async {
      final file =
          await writeReport({'findings': List.generate(120, (i) => i)});

      final resultString = await tool.execute({
        'file': file,
        'path': 'findings',
        'offset': 100,
        'limit': 10,
      });
      final result = jsonDecode(resultString) as Map<String, dynamic>;

      expect((result['data'] as List),
          equals([100, 101, 102, 103, 104, 105, 106, 107, 108, 109]));
    });

    test('caps limit at the maximum allowed value', () async {
      final file =
          await writeReport({'findings': List.generate(1000, (i) => i)});

      final resultString = await tool.execute({
        'file': file,
        'path': 'findings',
        'limit': 5000,
      });
      final result = jsonDecode(resultString) as Map<String, dynamic>;

      expect(result['limit'], equals(500));
    });

    test('returns an error with available keys for a missing path', () async {
      final file = await writeReport({'summary': {}, 'findings': []});

      final resultString =
          await tool.execute({'file': file, 'path': 'nonexistent'});
      final result = jsonDecode(resultString) as Map<String, dynamic>;

      expect(result['error'], equals('Path not found'));
      final availableKeys = result['available_keys'] as Map<String, dynamic>;
      expect(availableKeys['top_level_keys'],
          containsAll(['summary', 'findings']));
    });

    test('returns an error for a missing file', () async {
      final missingPath = p.join(reportsDir.path, 'does_not_exist.json');

      final resultString = await tool.execute({'file': missingPath});
      final result = jsonDecode(resultString) as Map<String, dynamic>;

      expect(result['error'], equals('File not found'));
    });

    test('rejects files outside a .rw_git/reports directory', () async {
      final outsideFile = File(p.join(tempDir.path, 'outside.json'));
      await outsideFile.writeAsString(jsonEncode({'a': 1}));

      final resultString = await tool.execute({'file': outsideFile.path});
      final result = jsonDecode(resultString) as Map<String, dynamic>;

      expect(result['error'], contains('Security violation'));
    });
  });
}
