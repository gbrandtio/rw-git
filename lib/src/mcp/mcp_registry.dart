import 'mcp_prompt.dart';
import 'mcp_tool.dart';

/// mcp_registry.dart
/// Manages the registration and lookup of MCP tools and prompts.

class McpRegistry {
  final Map<String, McpTool> _tools = {};
  final Map<String, McpPrompt> _prompts = {};

  /// Registers a new tool into the registry.
  void registerTool(McpTool tool) {
    _tools[tool.name] = tool;
  }

  /// Retrieves a tool by its name. Returns null if not found.
  McpTool? getTool(String name) {
    return _tools[name];
  }

  /// Returns a list of all registered tools formatted for the 'tools/list' MCP method.
  List<Map<String, dynamic>> getToolListings() {
    return _tools.values.map((tool) {
      return {
        'name': tool.name,
        'description': tool.description,
        'inputSchema': tool.inputSchema,
      };
    }).toList();
  }

  /// Registers a new prompt into the registry.
  void registerPrompt(McpPrompt prompt) {
    _prompts[prompt.name] = prompt;
  }

  /// Retrieves a prompt by its name. Returns null if not found.
  McpPrompt? getPrompt(String name) {
    return _prompts[name];
  }

  /// Returns a list of all registered prompts formatted for the 'prompts/list' MCP method.
  List<Map<String, dynamic>> getPromptListings() {
    return _prompts.values.map((prompt) {
      return {
        'name': prompt.name,
        'description': prompt.description,
      };
    }).toList();
  }
}
