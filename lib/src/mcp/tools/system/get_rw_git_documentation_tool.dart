import '../../../constants.dart';
import '../../mcp_registry.dart';
import '../../mcp_tool.dart';

/// get_rw_git_documentation_tool.dart
/// Provides detailed documentation for the RwGit facade out-of-the-box operations and MCP tools.

class GetRwGitDocumentationTool implements McpTool {
  final McpRegistry registry;

  GetRwGitDocumentationTool(this.registry);
  @override
  String get name => 'get_rw_git_documentation';

  @override
  String get description =>
      'Retrieve detailed descriptions and parameter requirements for all RwGit facade out-of-the-box operations and MCP tools. '
      'To invoke this tool, no arguments are required.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {},
        'required': [],
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final toolListings = registry.getToolListings();
    final toolsMarkdown = toolListings
        .where((tool) => tool['name'] != 'get_rw_git_documentation')
        .map((tool) => '- **${tool['name']}**: ${tool['description']}')
        .join('\n');

    return rwGitDocumentationTemplate.replaceAll(
      '{{toolsMarkdown}}',
      toolsMarkdown,
    );
  }
}
