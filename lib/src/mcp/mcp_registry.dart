import 'mcp_tool.dart';

/// mcp_registry.dart
/// Manages the registration and lookup of MCP tools.

class McpRegistry {
  final Map<String, McpTool> _tools = {};

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
}
