import '../mcp_request_context.dart';
import 'mcp_rule.dart';

/// resources_list_rule.dart
/// Handles `resources/list`, returning the registry's resource listings.
class ResourcesListRule implements McpRule {
  @override
  bool matches(String? method) => method == 'resources/list';

  @override
  Future<void> handle(
      McpRequestContext ctx, dynamic id, Map<String, dynamic> params) async {
    ctx.sendResponse(id, {'resources': ctx.registry.resources.listings()});
  }
}
