/// mcp_tool.dart
/// Defines the strategy interface for all MCP tools.
library;

abstract interface class McpTool {
  /// The unique name of the tool, used for routing the JSON-RPC request.
  String get name;

  /// A brief description of what the tool does.
  String get description;

  /// The JSON Schema describing the input arguments expected by this tool.
  Map<String, dynamic> get inputSchema;

  /// Executes the tool with the given arguments.
  Future<String> execute(Map<String, dynamic> arguments);
}

/// Optional, standard MCP metadata a tool may expose in the `tools/list`
/// response. Tools opt in by being wrapped so the registry can advertise
/// `annotations` (e.g. `readOnlyHint`, `idempotentHint`) and an `outputSchema`
/// without forcing every [McpTool] implementation to define them.
mixin McpToolMetadata {
  /// MCP tool annotations (behavioural hints such as `readOnlyHint`).
  Map<String, dynamic>? get annotations => null;

  /// JSON Schema describing the tool's structured output, when its shape is
  /// stable enough to be useful. Kept compact to respect the context budget.
  Map<String, dynamic>? get outputSchema => null;
}
