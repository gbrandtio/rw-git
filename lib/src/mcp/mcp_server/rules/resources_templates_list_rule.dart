import '../mcp_request_context.dart';
import 'mcp_rule.dart';

/// resources_templates_list_rule.dart
/// Handles `resources/templates/list`. The server does not expose dynamic
/// resource templates (ADR-none), so it always returns an empty list rather
/// than falling through to `Method not found`, which some MCP clients
/// (e.g. continue.dev) treat as a hard connection error.
class ResourcesTemplatesListRule implements McpRule {
  @override
  bool matches(String? method) => method == 'resources/templates/list';

  @override
  Future<void> handle(
      McpRequestContext ctx, dynamic id, Map<String, dynamic> params) async {
    ctx.sendResponse(id, {'resourceTemplates': []});
  }
}
