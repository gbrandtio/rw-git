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
      ctx.sendToolResult(id, resultText);
    } on RwGitException catch (e) {
      ctx.sendError(id, jsonRpcServerError,
          'Git error (code ${e.exitCode}): ${e.message}\\n${e.stderr}');
    } catch (e) {
      ctx.sendError(id, jsonRpcServerError, 'Tool execution error: $e');
    }
  }
}
