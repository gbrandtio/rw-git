// ignore_for_file: avoid_dynamic_calls
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

/// A trivial read-only tool used to populate the registry for pagination tests.
class _StubTool implements McpTool {
  @override
  final String name;
  _StubTool(this.name);
  @override
  String get description => 'stub';
  @override
  Map<String, dynamic> get inputSchema => {'type': 'object', 'properties': {}};
  @override
  Future<String> execute(Map<String, dynamic> args) async => '{}';
}

void main() {
  late StreamController<List<int>> input;
  late StreamController<List<int>> output;
  late IOSink outSink;

  setUp(() {
    input = StreamController<List<int>>();
    output = StreamController<List<int>>.broadcast();
    outSink = IOSink(output.sink);
  });

  void send(Map<String, dynamic> json) =>
      input.add(utf8.encode('${jsonEncode(json)}\n'));

  Future<Map<String, dynamic>> firstResponse() async {
    final line = await output.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .first;
    return jsonDecode(line) as Map<String, dynamic>;
  }

  McpServer makeServer(McpRegistry registry, {int? pageSize}) => McpServer(
        registry: registry,
        inputStream: input.stream,
        outputSink: outSink,
        errorSink: IOSink(StreamController<List<int>>().sink),
        toolsPageSize: pageSize,
      );

  test('initialize echoes a supported requested protocol version', () async {
    makeServer(McpRegistry()).start();
    send({
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'initialize',
      'params': {'protocolVersion': '2024-11-05'},
    });
    final res = await firstResponse();
    expect(res['result']['protocolVersion'], '2024-11-05');
  });

  test(
      'unrecognized notification (no id) is silently dropped, not replied '
      'to with id: null', () async {
    makeServer(McpRegistry()).start();
    send({'jsonrpc': '2.0', 'method': 'notifications/roots/list_changed'});
    send({
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'initialize',
      'params': {'protocolVersion': '2024-11-05'},
    });
    // The notification must not have produced any output: the first line on
    // the stream is the initialize response, not a malformed error reply.
    final res = await firstResponse();
    expect(res['result']['protocolVersion'], '2024-11-05');
  });

  test('unrecognized request (has id) still gets Method not found', () async {
    makeServer(McpRegistry()).start();
    send({'jsonrpc': '2.0', 'id': 1, 'method': 'totally/unknown'});
    final res = await firstResponse();
    expect(res['id'], 1);
    expect(res['error']['code'], -32601);
  });

  test('tools/list paginates with an opaque nextCursor', () async {
    final registry = McpRegistry();
    for (var i = 0; i < 5; i++) {
      registry.registerTool(_StubTool('tool_$i'));
    }
    makeServer(registry, pageSize: 2).start();

    send({'jsonrpc': '2.0', 'id': 1, 'method': 'tools/list'});
    final page1 = await firstResponse();
    expect((page1['result']['tools'] as List).length, 2);
    final cursor = page1['result']['nextCursor'];
    expect(cursor, isNotNull);
  });

  test('tools/list rejects a malformed cursor', () async {
    final registry = McpRegistry();
    for (var i = 0; i < 5; i++) {
      registry.registerTool(_StubTool('tool_$i'));
    }
    makeServer(registry, pageSize: 2).start();
    send({
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'tools/list',
      'params': {'cursor': '!!!not-base64!!!'},
    });
    final res = await firstResponse();
    expect(res['error']['code'], -32602);
  });

  test('resources/read returns a registered offloaded report', () async {
    final dir = Directory.systemTemp.createTempSync('rw_git_res_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/report.json')
      ..writeAsStringSync('{"hello":"world"}');

    final registry = McpRegistry();
    final uri = registry.resources.register(file.path);

    makeServer(registry).start();
    send({
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'resources/read',
      'params': {'uri': uri},
    });
    final res = await firstResponse();
    final contents = res['result']['contents'] as List;
    expect(contents.first['uri'], uri);
    expect(contents.first['text'], contains('world'));
  });

  test('resources/read rejects an unregistered uri', () async {
    makeServer(McpRegistry()).start();
    send({
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'resources/read',
      'params': {'uri': 'file:///etc/passwd'},
    });
    final res = await firstResponse();
    expect(res['error']['code'], -32002);
  });

  Future<Map<String, dynamic>> callTool(
    McpRegistry registry,
    String toolName,
  ) async {
    makeServer(registry).start();
    send({
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'tools/call',
      'params': {'name': toolName, 'arguments': <String, dynamic>{}},
    });
    return firstResponse();
  }

  test(
      'tools/call returns structuredContent alongside text when the tool '
      'advertises an outputSchema (MCP 2025-06-18)', () async {
    final registry = McpRegistry()
      ..registerTool(
        McpToolWithMetadata(
          _JsonPayloadTool(),
          outputSchema: {
            'type': 'object',
            'properties': {
              'answer': {'type': 'integer'},
            },
          },
        ),
      );

    final res = await callTool(registry, 'json_payload');
    final result = res['result'] as Map<String, dynamic>;
    // The text block stays for backward compatibility...
    expect((result['content'] as List).first['text'], contains('42'));
    // ...and the same payload is delivered machine-readable.
    final structured = result['structuredContent'] as Map<String, dynamic>;
    expect(structured['answer'], 42);
  });

  test(
    'tools/call omits structuredContent when no outputSchema is declared',
    () async {
      final registry = McpRegistry()..registerTool(_JsonPayloadTool());

      final res = await callTool(registry, 'json_payload');
      final result = res['result'] as Map<String, dynamic>;
      expect(result.containsKey('structuredContent'), isFalse);
      expect((result['content'] as List).first['text'], contains('42'));
    },
  );

  test(
      'tools/call omits structuredContent for non-object output even when a '
      'schema is declared', () async {
    final registry = McpRegistry()
      ..registerTool(
        McpToolWithMetadata(
          _MarkdownTool(),
          outputSchema: const {
            'type': 'object',
            'properties': <String, dynamic>{},
          },
        ),
      );

    final res = await callTool(registry, 'markdown_tool');
    final result = res['result'] as Map<String, dynamic>;
    expect(result.containsKey('structuredContent'), isFalse);
    expect((result['content'] as List).first['text'], contains('# Heading'));
  });
}

/// Returns a small JSON object, the shape a schema-declaring tool promises.
class _JsonPayloadTool implements McpTool {
  @override
  String get name => 'json_payload';
  @override
  String get description => 'stub';
  @override
  Map<String, dynamic> get inputSchema => {'type': 'object', 'properties': {}};
  @override
  Future<String> execute(Map<String, dynamic> args) async =>
      jsonEncode({'answer': 42});
}

/// Returns non-JSON text, like get_rw_git_documentation.
class _MarkdownTool implements McpTool {
  @override
  String get name => 'markdown_tool';
  @override
  String get description => 'stub';
  @override
  Map<String, dynamic> get inputSchema => {'type': 'object', 'properties': {}};
  @override
  Future<String> execute(Map<String, dynamic> args) async => '# Heading';
}
