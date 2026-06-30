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
    // Padded well above offloadSizeThresholdBytes so this tool's output is
    // always treated as "large" and offloaded by default.
    return jsonEncode({
      'mock_data': 'massive JSON payload',
      'padding': 'x' * 9000,
    });
  }
}

class MockSmallTool implements McpTool {
  @override
  String get name => 'mock_small_tool';

  @override
  String get description => 'A mock tool with a small payload for testing.';

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
    return jsonEncode({'mock_data': 'tiny payload'});
  }
}

class MockStructuredTool implements McpTool {
  @override
  String get name => 'mock_structured_tool';

  @override
  String get description => 'A mock tool with a structured payload.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'directory': {'type': 'string'}
        },
        'required': ['directory'],
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    return jsonEncode({
      'summary': {'total': 5},
      'findings': List.generate(3, (i) => 'finding_$i'),
      'padding': 'x' * 9000,
    });
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
    test('modifies inputSchema to include output_file and return_full_json',
        () {
      final schema = decorator.inputSchema;
      final properties = schema['properties'] as Map<String, dynamic>;

      expect(properties.containsKey('output_file'), isTrue);
      expect(properties.containsKey('return_full_json'), isTrue);
    });

    test('modifies description to include offloading hint', () {
      final desc = decorator.description;
      expect(desc, contains('offloaded to disk'));
      expect(desc, contains('get_rw_git_documentation'));
      expect(desc, contains('return_full_json'));
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

    test('returns small payloads inline instead of offloading', () async {
      final smallDecorator = McpToolFileOffloadDecorator(MockSmallTool());

      final resultString = await smallDecorator.execute({
        'directory': tempDir.path,
      });

      final result = jsonDecode(resultString) as Map<String, dynamic>;
      expect(result['mock_data'], equals('tiny payload'));
      expect(result.containsKey('status'), isFalse);

      final reportsDir = Directory(p.join(tempDir.path, '.rw_git', 'reports'));
      expect(await reportsDir.exists(), isFalse);
    });

    test('offloads large payloads to disk', () async {
      final resultString = await decorator.execute({
        'directory': tempDir.path,
      });

      final result = jsonDecode(resultString) as Map<String, dynamic>;
      expect(result['status'], equals('success'));
      expect(result['file'], isNotNull);
    });

    test('still offloads a small payload when output_file is explicit',
        () async {
      final smallDecorator = McpToolFileOffloadDecorator(MockSmallTool());
      final specificPath = p.join(tempDir.path, 'forced_small.json');

      final resultString = await smallDecorator.execute({
        'directory': tempDir.path,
        'output_file': specificPath,
      });

      final result = jsonDecode(resultString) as Map<String, dynamic>;
      expect(result['status'], equals('success'));
      expect(await File(specificPath).exists(), isTrue);
    });

    test('return_full_json=true skips offload and returns raw output',
        () async {
      final resultString = await decorator.execute({
        'directory': tempDir.path,
        'return_full_json': true,
      });

      expect(resultString, contains('massive JSON payload'));
      final reportsDir = Directory(p.join(tempDir.path, '.rw_git', 'reports'));
      expect(await reportsDir.exists(), isFalse);
    });

    test(
        'return_full_json=true takes precedence even with output_file provided',
        () async {
      final specificPath = p.join(tempDir.path, 'should_not_exist.json');

      final resultString = await decorator.execute({
        'directory': tempDir.path,
        'output_file': specificPath,
        'return_full_json': true,
      });

      expect(resultString, contains('massive JSON payload'));
      expect(await File(specificPath).exists(), isFalse);
    });

    test('includes a structural preview in the offload summary', () async {
      final structuredDecorator =
          McpToolFileOffloadDecorator(MockStructuredTool());

      final resultString = await structuredDecorator.execute({
        'directory': tempDir.path,
      });

      final result = jsonDecode(resultString) as Map<String, dynamic>;
      final preview = result['preview'] as Map<String, dynamic>;
      final topLevelKeys = preview['top_level_keys'] as List;
      final arrayLengths = preview['array_lengths'] as Map;

      expect(topLevelKeys, containsAll(['summary', 'findings', 'padding']));
      expect(arrayLengths['findings'], equals(3));
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
