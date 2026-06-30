import 'mcp_tool.dart';

/// Wraps any [McpTool] to attach standard MCP [McpToolMetadata]
/// (`annotations` / `outputSchema`) without modifying the tool itself.
///
/// Applied as the outermost wrapper at registration time so the registry sees
/// the metadata while name/description/inputSchema/execute still delegate to
/// the wrapped tool (typically an [McpToolFileOffloadDecorator]).
class McpToolWithMetadata with McpToolMetadata implements McpTool {
  final McpTool _inner;

  @override
  final Map<String, dynamic>? annotations;

  @override
  final Map<String, dynamic>? outputSchema;

  McpToolWithMetadata(this._inner, {this.annotations, this.outputSchema});

  @override
  String get name => _inner.name;

  @override
  String get description => _inner.description;

  @override
  Map<String, dynamic> get inputSchema => _inner.inputSchema;

  @override
  Future<String> execute(Map<String, dynamic> arguments) =>
      _inner.execute(arguments);
}
