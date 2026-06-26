import 'dart:convert';
import 'dart:io';

import '../../rw_git.dart';

/// mcp_server.dart
/// Handles the Model Context Protocol (MCP) JSON-RPC communication loop over standard I/O.
class McpServer {
  final McpRegistry registry;
  final Stream<List<int>> inputStream;
  final IOSink outputSink;
  final IOSink errorSink;

  McpServer({
    required this.registry,
    Stream<List<int>>? inputStream,
    IOSink? outputSink,
    IOSink? errorSink,
  })  : inputStream = inputStream ?? stdin,
        outputSink = outputSink ?? stdout,
        errorSink = errorSink ?? stderr;

  /// Starts listening to the input stream for JSON-RPC messages.
  void start() {
    inputStream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) async {
      try {
        final request = jsonDecode(line);
        if (request is! Map<String, dynamic>) return;

        await _handleRequest(request);
      } catch (e) {
        errorSink.writeln('Error processing message: $e');
      }
    });
  }

  Future<void> _handleRequest(Map<String, dynamic> request) async {
    final id = request['id'];
    final method = request['method'];
    final params =
        (request['params'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    if (method == 'initialize') {
      _sendResponse(id, {
        'protocolVersion': '2024-11-05',
        'capabilities': {'tools': {}, 'resources': {}, 'prompts': {}},
        'serverInfo': {'name': 'rw_git_mcp', 'version': '1.0.0'}
      });
    } else if (method == 'notifications/initialized') {
      // Just acknowledge
    } else if (method == 'ping') {
      _sendResponse(id, {});
    } else if (method == 'resources/list') {
      _sendResponse(id, {'resources': []});
    } else if (method == 'prompts/list') {
      _sendResponse(id, {'prompts': []});
    } else if (method == 'tools/list') {
      _sendResponse(id, {
        'tools': registry.getToolListings(),
      });
    } else if (method == 'tools/call') {
      final toolName = params['name'] as String?;
      final args = params['arguments'] as Map<String, dynamic>? ?? {};

      if (toolName == null) {
        _sendError(id, -32602, 'Invalid params: missing tool name');
        return;
      }

      final tool = registry.getTool(toolName);
      if (tool == null) {
        _sendError(id, 32601, 'Method not found: $toolName');
        return;
      }

      try {
        final resultText = await tool.execute(args);
        _sendToolResult(id, resultText);
      } on RwGitException catch (e) {
        _sendError(id, -32000,
            'Git error (code ${e.exitCode}): ${e.message}\\n${e.stderr}');
      } catch (e) {
        _sendError(id, -32000, 'Tool execution error: $e');
      }
    } else {
      _sendError(id, -32601, 'Method not found: $method');
    }
  }

  void _sendResponse(dynamic id, Map<String, dynamic> result) {
    outputSink.writeln(jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'result': result,
    }));
  }

  void _sendToolResult(dynamic id, String text) {
    outputSink.writeln(jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'result': {
        'content': [
          {'type': 'text', 'text': text}
        ]
      }
    }));
  }

  void _sendError(dynamic id, int code, String message) {
    outputSink.writeln(jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'error': {'code': code, 'message': message}
    }));
  }
}
