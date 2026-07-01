import '../mcp_request_context.dart';
import 'mcp_rule.dart';

/// ping_rule.dart
/// Handles the `ping` keep-alive method with an empty response.
class PingRule implements McpRule {
  @override
  bool matches(String? method) => method == 'ping';

  @override
  Future<void> handle(
      McpRequestContext ctx, dynamic id, Map<String, dynamic> params) async {
    ctx.sendResponse(id, {});
  }
}
