import '../mcp_request_context.dart';
import 'mcp_rule.dart';

/// prompts_get_rule.dart
/// Handles `prompts/get`, resolving a named prompt from the registry.
class PromptsGetRule implements McpRule {
  @override
  bool matches(String? method) => method == 'prompts/get';

  @override
  Future<void> handle(
      McpRequestContext ctx, dynamic id, Map<String, dynamic> params) async {
    final promptName = params['name'] as String?;
    if (promptName == null) {
      ctx.sendError(id, -32602, 'Invalid params: missing prompt name');
      return;
    }

    final prompt = ctx.registry.getPrompt(promptName);
    if (prompt == null) {
      ctx.sendError(id, 32601, 'Prompt not found: $promptName');
      return;
    }

    ctx.sendResponse(id, {
      'description': prompt.description,
      'messages': prompt.messages,
    });
  }
}
