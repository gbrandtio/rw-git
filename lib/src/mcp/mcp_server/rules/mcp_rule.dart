import '../mcp_request_context.dart';

/// mcp_rule.dart
/// A single dispatch rule in the Rules design pattern: knows whether it
/// applies to a given JSON-RPC method, and how to handle it if so.
abstract class McpRule {
  bool matches(String? method);

  Future<void> handle(
    McpRequestContext ctx,
    dynamic id,
    Map<String, dynamic> params,
  );
}
