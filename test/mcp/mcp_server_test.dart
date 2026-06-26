// ignore_for_file: avoid_dynamic_calls, unnecessary_cast
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

class MockMcpTool implements McpTool {
  @override
  final String name;

  @override
  final String description = 'desc';

  @override
  final Map<String, dynamic> inputSchema = {};

  final Future<String> Function(Map<String, dynamic>) onExecute;

  MockMcpTool(this.name, this.onExecute);

  @override
  Future<String> execute(Map<String, dynamic> arguments) =>
      onExecute(arguments);
}

void main() {
  group('McpServer', () {
    late McpRegistry registry;
    late StreamController<List<int>> inputStreamController;
    late StreamController<List<int>> outputStreamController;
    late StreamController<List<int>> errorStreamController;
    late IOSink outputSink;
    late IOSink errorSink;
    late McpServer server;

    setUp(() {
      registry = McpRegistry();
      inputStreamController = StreamController<List<int>>.broadcast();
      outputStreamController = StreamController<List<int>>.broadcast();
      errorStreamController = StreamController<List<int>>.broadcast();
      outputSink = IOSink(outputStreamController.sink);
      errorSink = IOSink(errorStreamController.sink);

      server = McpServer(
        registry: registry,
        inputStream: inputStreamController.stream,
        outputSink: outputSink,
        errorSink: errorSink,
      );
    });

    tearDown(() async {
      await inputStreamController.close();
      await outputSink.close();
      await errorSink.close();
    });

    void sendInput(dynamic json) {
      inputStreamController.add(utf8.encode('${jsonEncode(json)}\n'));
    }

    test('responds to initialize', () async {
      server.start();
      sendInput({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
      });

      final outputLines = await outputStreamController.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .take(1)
          .toList();

      final response = jsonDecode(outputLines.first) as Map<String, dynamic>;
      expect(response['id'], 1);
      expect(response['result']['protocolVersion'], '2024-11-05');
    });

    test('responds to ping', () async {
      server.start();
      sendInput({
        'jsonrpc': '2.0',
        'id': 99,
        'method': 'ping',
      });

      final outputLines = await outputStreamController.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .take(1)
          .toList();

      final response = jsonDecode(outputLines.first) as Map<String, dynamic>;
      expect(response['id'], 99);
      expect(response['result'], isEmpty);
    });

    test('responds to tools/list', () async {
      registry.registerTool(MockMcpTool('test_tool', (_) async => ''));
      server.start();

      sendInput({
        'jsonrpc': '2.0',
        'id': 2,
        'method': 'tools/list',
      });

      final outputLines = await outputStreamController.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .take(1)
          .toList();

      final response = jsonDecode(outputLines.first) as Map<String, dynamic>;
      expect(response['id'], 2);
      expect(response['result']['tools'][0]['name'], 'test_tool');
    });

    test('responds to tools/call successfully', () async {
      registry.registerTool(MockMcpTool(
          'test_tool', (args) async => 'Tool output: ${args["param"]}'));
      server.start();

      sendInput({
        'jsonrpc': '2.0',
        'id': 3,
        'method': 'tools/call',
        'params': {
          'name': 'test_tool',
          'arguments': {'param': 'value'}
        }
      });

      final outputLines = await outputStreamController.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .take(1)
          .toList();

      final response = jsonDecode(outputLines.first) as Map<String, dynamic>;
      expect(response['id'], 3);
      expect(response['result']['content'][0]['text'], 'Tool output: value');
    });

    test('tools/call missing name returns error', () async {
      server.start();

      sendInput({
        'jsonrpc': '2.0',
        'id': 4,
        'method': 'tools/call',
        'params': {'arguments': {}}
      });

      final outputLines = await outputStreamController.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .take(1)
          .toList();

      final response = jsonDecode(outputLines.first) as Map<String, dynamic>;
      expect(response['error']['code'], -32602);
      expect(response['error']['message'], contains('missing tool name'));
    });

    test('tools/call unknown tool returns error', () async {
      server.start();

      sendInput({
        'jsonrpc': '2.0',
        'id': 5,
        'method': 'tools/call',
        'params': {'name': 'unknown_tool'}
      });

      final outputLines = await outputStreamController.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .take(1)
          .toList();

      final response = jsonDecode(outputLines.first) as Map<String, dynamic>;
      expect(response['error']['code'], 32601);
      expect(response['error']['message'],
          contains('Method not found: unknown_tool'));
    });

    test('tools/call tool throws RwGitException returns error', () async {
      registry.registerTool(MockMcpTool(
          'test_tool',
          (_) async => throw RwGitException(
              message: 'Custom Git Error',
              exitCode: 128,
              stderr: 'stderr msg')));
      server.start();

      sendInput({
        'jsonrpc': '2.0',
        'id': 6,
        'method': 'tools/call',
        'params': {'name': 'test_tool'}
      });

      final outputLines = await outputStreamController.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .take(1)
          .toList();

      final response = jsonDecode(outputLines.first) as Map<String, dynamic>;
      expect(response['error']['code'], -32000);
      expect(response['error']['message'], contains('Custom Git Error'));
    });

    test('tools/call tool throws generic exception returns error', () async {
      registry.registerTool(MockMcpTool(
          'test_tool', (_) async => throw Exception('Generic error')));
      server.start();

      sendInput({
        'jsonrpc': '2.0',
        'id': 7,
        'method': 'tools/call',
        'params': {'name': 'test_tool'}
      });

      final outputLines = await outputStreamController.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .take(1)
          .toList();

      final response = jsonDecode(outputLines.first) as Map<String, dynamic>;
      expect(response['error']['code'], -32000);
      expect(response['error']['message'], contains('Generic error'));
    });

    test('unknown method returns error', () async {
      server.start();

      sendInput({
        'jsonrpc': '2.0',
        'id': 8,
        'method': 'unknown/method',
      });

      final outputLines = await outputStreamController.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .take(1)
          .toList();

      final response = jsonDecode(outputLines.first) as Map<String, dynamic>;
      expect(response['error']['code'], -32601);
      expect(response['error']['message'],
          contains('Method not found: unknown/method'));
    });

    test('notifications/initialized is ignored without response', () async {
      server.start();

      sendInput({
        'jsonrpc': '2.0',
        'method': 'notifications/initialized',
      });
      // Give it a tick to process
      await Future.delayed(const Duration(milliseconds: 10));
      // No output should be sent
      // We check this by sending another request and expecting only one response
      sendInput({
        'jsonrpc': '2.0',
        'id': 9,
        'method': 'initialize',
      });

      final outputLines = await outputStreamController.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .take(1)
          .toList();

      final response = jsonDecode(outputLines.first) as Map<String, dynamic>;
      expect(response['id'], 9);
    });

    test('invalid json logs to errorSink', () async {
      server.start();

      inputStreamController.add(utf8.encode('invalid json\n'));

      final errorLines = await errorStreamController.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .take(1)
          .toList();

      expect(errorLines.first, contains('Error processing message'));
    });

    test('invalid request type is ignored', () async {
      server.start();

      sendInput([1, 2, 3]); // List instead of map

      // Give it a tick to process
      await Future.delayed(const Duration(milliseconds: 10));
      // No output should be sent
      sendInput({
        'jsonrpc': '2.0',
        'id': 10,
        'method': 'initialize',
      });

      final outputLines = await outputStreamController.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .take(1)
          .toList();

      final response = jsonDecode(outputLines.first) as Map<String, dynamic>;
      expect(response['id'], 10);
    });

    test('McpServer creates successfully with default arguments', () {
      final defaultServer = McpServer(registry: registry);
      expect(defaultServer, isNotNull);
    });
  });
}
