/// mcp_prompt.dart
/// Defines the strategy interface for all MCP prompts.
library;

abstract interface class McpPrompt {
  /// The unique name of the prompt, used for routing the JSON-RPC request.
  String get name;

  /// A brief description of what the prompt provides.
  String get description;

  /// The messages comprising the prompt.
  List<Map<String, dynamic>> get messages;
}
