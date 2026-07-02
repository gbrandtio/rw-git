import 'dart:convert';
import 'dart:io';

import '../../../rw_git.dart';

/// mcp_request_context.dart
/// Shared context passed to every [McpRule], bundling the registry, output
/// sink, and the low-level JSON-RPC response helpers rules need.
class McpRequestContext {
  final McpRegistry registry;
  final IOSink outputSink;
  final int? toolsPageSize;

  /// Minimum severity forwarded to the host as `notifications/message`
  /// (ADR-0012). Defaults to warning so an idle host is not flooded with
  /// per-command debug events; hosts opt into more via `logging/setLevel`.
  McpLogLevel minimumLogLevel = McpLogLevel.warning;

  McpRequestContext({
    required this.registry,
    required this.outputSink,
    this.toolsPageSize,
  });

  /// Emits an MCP `notifications/message` for [level] when it clears
  /// [minimumLogLevel]; silently drops it otherwise, as the host asked.
  void sendLogNotification(McpLogLevel level, String message, {Object? error}) {
    if (level.index < minimumLogLevel.index) return;
    outputSink.writeln(jsonEncode({
      'jsonrpc': '2.0',
      'method': 'notifications/message',
      'params': {
        'level': level.wireName,
        'logger': RwGitLogger.loggerName,
        'data': {
          'message': message,
          if (error != null) 'error': error.toString(),
        },
      },
    }));
  }

  void sendResponse(dynamic id, Map<String, dynamic> result) {
    outputSink.writeln(jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'result': result,
    }));
  }

  /// Sends a `tools/call` result. [text] is always delivered as the standard
  /// text content block; [structuredContent] is additionally attached when a
  /// tool advertises an `outputSchema`, per MCP 2025-06-18 (tools declaring a
  /// schema should return machine-readable structured output alongside the
  /// text for backward compatibility).
  void sendToolResult(dynamic id, String text,
      {Map<String, dynamic>? structuredContent}) {
    outputSink.writeln(jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'result': {
        'content': [
          {'type': 'text', 'text': text}
        ],
        if (structuredContent != null) 'structuredContent': structuredContent,
      }
    }));
  }

  void sendError(dynamic id, int code, String message) {
    outputSink.writeln(jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'error': {'code': code, 'message': message}
    }));
  }

  String encodeCursor(int offset) =>
      base64Url.encode(utf8.encode(offset.toString()));

  int? decodeCursor(dynamic cursor) {
    if (cursor is! String) return null;
    try {
      return int.tryParse(utf8.decode(base64Url.decode(cursor)));
    } catch (_) {
      return null;
    }
  }
}
