import '../mcp_request_context.dart';
import 'mcp_rule.dart';

/// notifications_initialized_rule.dart
/// Acknowledges the `notifications/initialized` notification. No response
/// is sent, per the JSON-RPC notification contract.
class NotificationsInitializedRule implements McpRule {
  @override
  bool matches(String? method) => method == 'notifications/initialized';

  @override
  Future<void> handle(
    McpRequestContext ctx,
    dynamic id,
    Map<String, dynamic> params,
  ) async {}
}
