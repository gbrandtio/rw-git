import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:rw_git/src/mcp/mcp_tool.dart';
import 'package:rw_git/src/mcp/mcp_tool_file_offload_decorator.dart';

class MockTool implements McpTool {
  @override
  String get name => 'mock_tool';

  @override
  String get description => 'A mock tool for testing.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'directory': {
            'type': 'string',
            'description': 'The repo directory.',
          }
        },
        'required': ['directory'],
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    return jsonEncode({'mock_data': 'massive JSON payload'});
  }
}

void main() {
  late Directory tempDir;
  late MockTool mockTool;
  late McpToolFileOffloadDecorator decorator;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mcp_decorator_test_');
    mockTool = MockTool();
    decorator = McpToolFileOffloadDecorator(mockTool);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('McpToolFileOffloadDecorator', () {
    test('modifies inputSchema to include output_file', () {
      final schema = decorator.inputSchema;
      final properties = schema['properties'] as Map<String, dynamic>;

      expect(properties.containsKey('output_file'), isTrue);
    });

    test('modifies description to include offloading hint', () {
      final desc = decorator.description;
      expect(desc, contains('CONTEXT OFFLOADING'));
    });

    test('writes to auto-generated file by default and returns summary',
        () async {
      final resultString = await decorator.execute({
        'directory': tempDir.path,
      });

      final result = jsonDecode(resultString) as Map<String, dynamic>;
      expect(result['status'], equals('success'));
      expect(result['file'], isNotNull);

      final writtenFile = File(result['file'] as String);
      expect(await writtenFile.exists(), isTrue);

      final content = await writtenFile.readAsString();
      expect(content, contains('massive JSON payload'));
    });

    test('writes to specific output_file when provided securely', () async {
      final specificPath = p.join(tempDir.path, 'custom_report.json');

      final resultString = await decorator.execute({
        'directory': tempDir.path,
        'output_file': specificPath,
      });

      final result = jsonDecode(resultString) as Map<String, dynamic>;
      expect(result['status'], equals('success'));
      expect(result['file'], equals(specificPath));

      final writtenFile = File(specificPath);
      expect(await writtenFile.exists(), isTrue);
    });

    test('blocks path traversal in output_file', () async {
      final maliciousPath = p.join(tempDir.path, '..', 'etc', 'passwd');

      final resultString = await decorator.execute({
        'directory': tempDir.path,
        'output_file': maliciousPath,
      });

      final result = jsonDecode(resultString) as Map<String, dynamic>;
      expect(result['error'], contains('Security violation'));
    });

    test('returns decorator name', () {
      expect(decorator.name, equals('mock_tool'));
    });

    test('handles inputSchema without properties', () {
      final emptySchemaTool = MockEmptySchemaTool();
      final emptyDecorator = McpToolFileOffloadDecorator(emptySchemaTool);
      final schema = emptyDecorator.inputSchema;
      final properties = schema['properties'] as Map<String, dynamic>;
      expect(properties.containsKey('output_file'), isTrue);
    });

    test('uses file_path when directory is not provided', () async {
      final mockFilePath = p.join(tempDir.path, 'some_file.dart');
      final resultString = await decorator.execute({
        'file_path': mockFilePath,
      });
      final result = jsonDecode(resultString) as Map<String, dynamic>;
      expect(result['status'], equals('success'));
    });

    test('creates parent directory if it does not exist', () async {
      final specificPath =
          p.join(tempDir.path, 'nested', 'dir', 'custom_report.json');

      final resultString = await decorator.execute({
        'directory': tempDir.path,
        'output_file': specificPath,
      });

      final result = jsonDecode(resultString) as Map<String, dynamic>;
      expect(result['status'], equals('success'));
      expect(result['file'], equals(specificPath));

      final writtenFile = File(specificPath);
      expect(await writtenFile.exists(), isTrue);
    });

    test('handles FileSystemException on write', () async {
      final specificPath = p.join(tempDir.path, 'custom_report.json');
      // Create a directory at the specificPath so file creation throws FileSystemException
      await Directory(specificPath).create();

      final resultString = await decorator.execute({
        'directory': tempDir.path,
        'output_file': specificPath,
      });

      final result = jsonDecode(resultString) as Map<String, dynamic>;
      expect(result['error'], equals('Failed to write output to file'));
    });
  });
}

class MockEmptySchemaTool implements McpTool {
  @override
  String get name => 'empty';

  @override
  String get description => 'desc';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    return jsonEncode({'data': 'test'});
  }
}
