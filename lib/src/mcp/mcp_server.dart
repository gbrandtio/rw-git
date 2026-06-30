import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../rw_git.dart';
import '../constants.dart';

/// mcp_server.dart
/// Handles the Model Context Protocol (MCP) JSON-RPC communication loop over standard I/O.
class McpServer {
  final McpRegistry registry;
  final Stream<List<int>> inputStream;
  final IOSink outputSink;
  final IOSink errorSink;

  /// Optional page size for `tools/list`. When null, the full tool list is
  /// returned in a single response (backwards compatible). When set, the
  /// server paginates with an opaque `nextCursor`, letting tiny-context
  /// clients fetch the tool surface in chunks.
  final int? toolsPageSize;

  McpServer({
    required this.registry,
    Stream<List<int>>? inputStream,
    IOSink? outputSink,
    IOSink? errorSink,
    this.toolsPageSize,
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
      // Echo the client's protocol version when we support it; otherwise fall
      // back to our latest implemented revision.
      final requested = params['protocolVersion'] as String?;
      final version = supportedMcpProtocolVersions.contains(requested)
          ? requested!
          : mcpProtocolVersion;
      _sendResponse(id, {
        'protocolVersion': version,
        'capabilities': {
          'tools': {'listChanged': false},
          'resources': {'listChanged': false},
          'prompts': {'listChanged': false},
        },
        'serverInfo': {'name': 'rw_git_mcp', 'version': rwGitMcpVersion}
      });
    } else if (method == 'notifications/initialized') {
      // Just acknowledge
    } else if (method == 'ping') {
      _sendResponse(id, {});
    } else if (method == 'resources/list') {
      _sendResponse(id, {'resources': registry.resources.listings()});
    } else if (method == 'resources/read') {
      await _handleResourcesRead(id, params);
    } else if (method == 'prompts/list') {
      _sendResponse(id, {'prompts': registry.getPromptListings()});
    } else if (method == 'prompts/get') {
      final promptName = params['name'] as String?;
      if (promptName == null) {
        _sendError(id, -32602, 'Invalid params: missing prompt name');
        return;
      }

      final prompt = registry.getPrompt(promptName);
      if (prompt == null) {
        _sendError(id, 32601, 'Prompt not found: $promptName');
        return;
      }

      _sendResponse(id, {
        'description': prompt.description,
        'messages': prompt.messages,
      });
    } else if (method == 'tools/list') {
      _handleToolsList(id, params);
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

  /// Returns the tool listing, paginated when [toolsPageSize] is configured.
  void _handleToolsList(dynamic id, Map<String, dynamic> params) {
    final all = registry.getToolListings();
    final pageSize = toolsPageSize;

    if (pageSize == null || pageSize <= 0 || pageSize >= all.length) {
      _sendResponse(id, {'tools': all});
      return;
    }

    final cursor = params['cursor'];
    int start = 0;
    if (cursor != null) {
      final decoded = _decodeCursor(cursor);
      if (decoded == null || decoded < 0 || decoded > all.length) {
        _sendError(id, -32602, 'Invalid params: bad cursor');
        return;
      }
      start = decoded;
    }

    final end = min(start + pageSize, all.length);
    final result = <String, dynamic>{'tools': all.sublist(start, end)};
    if (end < all.length) {
      result['nextCursor'] = _encodeCursor(end);
    }
    _sendResponse(id, result);
  }

  /// Serves the contents of a previously offloaded report as an MCP resource.
  Future<void> _handleResourcesRead(
      dynamic id, Map<String, dynamic> params) async {
    final uri = params['uri'] as String?;
    if (uri == null) {
      _sendError(id, -32602, 'Invalid params: missing resource uri');
      return;
    }
    if (!registry.resources.contains(uri)) {
      _sendError(id, -32002, 'Resource not found: $uri');
      return;
    }
    final contents = await registry.resources.read(uri);
    if (contents == null) {
      _sendError(id, -32002, 'Resource no longer available: $uri');
      return;
    }
    _sendResponse(id, {
      'contents': [
        {'uri': uri, 'mimeType': 'application/json', 'text': contents}
      ]
    });
  }

  String _encodeCursor(int offset) =>
      base64Url.encode(utf8.encode(offset.toString()));

  int? _decodeCursor(dynamic cursor) {
    if (cursor is! String) return null;
    try {
      return int.tryParse(utf8.decode(base64Url.decode(cursor)));
    } catch (_) {
      return null;
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
