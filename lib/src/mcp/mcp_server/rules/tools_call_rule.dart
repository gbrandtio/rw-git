import 'dart:convert';

import '../../../../rw_git.dart';
import '../../../constants.dart';
import '../mcp_request_context.dart';
import 'mcp_rule.dart';

/// tools_call_rule.dart
/// Handles `tools/call`, invoking the named tool and translating exceptions
/// into JSON-RPC errors.
class ToolsCallRule implements McpRule {
  @override
  bool matches(String? method) => method == 'tools/call';

  @override
  Future<void> handle(
      McpRequestContext ctx, dynamic id, Map<String, dynamic> params) async {
    final toolName = params['name'] as String?;
    final args = params['arguments'] as Map<String, dynamic>? ?? {};

    if (toolName == null) {
      ctx.sendError(
          id, jsonRpcInvalidParams, 'Invalid params: missing tool name');
      return;
    }

    final tool = ctx.registry.getTool(toolName);
    if (tool == null) {
      ctx.sendError(id, jsonRpcMethodNotFound, 'Method not found: $toolName');
      return;
    }

    try {
      final resultText = await tool.execute(args);
      ctx.sendToolResult(id, resultText,
          structuredContent: _structuredContentFor(tool, resultText));
    } on RwGitException catch (e) {
      ctx.sendError(id, jsonRpcServerError,
          'Git error (code ${e.exitCode}): ${e.message}\\n${e.stderr}');
    } catch (e) {
      ctx.sendError(id, jsonRpcServerError, 'Tool execution error: $e');
    }
  }

  /// Decodes [resultText] into `structuredContent` only for tools that
  /// advertise an `outputSchema` (MCP 2025-06-18: a declared schema promises
  /// structured output). Non-JSON or non-object payloads yield null so the
  /// client falls back to the text content block.
  Map<String, dynamic>? _structuredContentFor(McpTool tool, String resultText) {
    // Widen to Object so the type test can promote to the metadata mixin,
    // which is not a subtype of McpTool.
    final Object candidate = tool;
    if (candidate is! McpToolMetadata || candidate.outputSchema == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(resultText);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}
