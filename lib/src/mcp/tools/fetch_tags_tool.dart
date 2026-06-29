import 'dart:convert';
import '../../../rw_git.dart';
import '../utils/mcp_argument_extensions.dart';

/// fetch_tags_tool.dart
/// Fetches all tags for a repository via MCP.

class FetchTagsTool implements McpTool {
  final RwGit rwGit;

  FetchTagsTool(this.rwGit);

  @override
  String get name => 'fetch_tags';

  @override
  String get description =>
      'Fetches all tags from the remote for the repository in the specified directory. '
      'For a complete guide on how to use the rw_git MCP tools, invoke the get_rw_git_documentation tool.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'localCheckoutDirectory': {
            'type': 'string',
            'description': 'The local directory containing the git repository.'
          }
        },
        'required': ['localCheckoutDirectory']
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final localDir = arguments.getStringArgument('localCheckoutDirectory');
    final tags = (await rwGit.fetchTags(localDir)).getOrThrow();
    return jsonEncode({'tags': tags});
  }
}
