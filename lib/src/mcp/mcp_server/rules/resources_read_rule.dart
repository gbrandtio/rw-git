import '../../../constants.dart';
import '../mcp_request_context.dart';
import 'mcp_rule.dart';

/// resources_read_rule.dart
/// Serves the contents of a previously offloaded report as an MCP resource.
class ResourcesReadRule implements McpRule {
  @override
  bool matches(String? method) => method == 'resources/read';

  @override
  Future<void> handle(
      McpRequestContext ctx, dynamic id, Map<String, dynamic> params) async {
    final uri = params['uri'] as String?;
    if (uri == null) {
      ctx.sendError(
          id, jsonRpcInvalidParams, 'Invalid params: missing resource uri');
      return;
    }
    if (!ctx.registry.resources.contains(uri)) {
      ctx.sendError(id, mcpResourceNotFound, 'Resource not found: $uri');
      return;
    }
    final contents = await ctx.registry.resources.read(uri);
    if (contents == null) {
      ctx.sendError(
          id, mcpResourceNotFound, 'Resource no longer available: $uri');
      return;
    }
    ctx.sendResponse(id, {
      'contents': [
        {'uri': uri, 'mimeType': 'application/json', 'text': contents}
      ]
    });
  }
}
