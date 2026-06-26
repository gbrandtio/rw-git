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
