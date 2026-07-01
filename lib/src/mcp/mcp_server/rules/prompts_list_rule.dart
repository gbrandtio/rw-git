import '../mcp_request_context.dart';
import 'mcp_rule.dart';

/// prompts_list_rule.dart
/// Handles `prompts/list`, returning the registry's prompt listings.
class PromptsListRule implements McpRule {
  @override
  bool matches(String? method) => method == 'prompts/list';

  @override
  Future<void> handle(
      McpRequestContext ctx, dynamic id, Map<String, dynamic> params) async {
    ctx.sendResponse(id, {'prompts': ctx.registry.getPromptListings()});
  }
}
