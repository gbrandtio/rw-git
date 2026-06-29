import 'dart:convert';
import '../../../rw_git.dart';
import '../utils/mcp_argument_extensions.dart';

/// get_contributions_by_author_tool.dart
/// Gets contributions by author via MCP.

class GetContributionsByAuthorTool implements McpTool {
  final RwGit rwGit;

  GetContributionsByAuthorTool(this.rwGit);

  @override
  String get name => 'get_contributions_by_author';

  @override
  String get description =>
      'Retrieves the shortlog summary of contributions by each author in the repository. '
      'For a complete guide on how to use the rw_git MCP tools, invoke the get_rw_git_documentation tool.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'directory': {
            'type': 'string',
            'description': 'The local directory containing the git repository.'
          }
        },
        'required': ['directory']
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final localDir = arguments.getStringArgument('directory');
    final contributions =
        (await rwGit.contributionsByAuthor(localDir)).getOrThrow();
    return jsonEncode({
      'contributions': contributions
          .map((c) => {
                'authorName': c.authorName,
                'numberOfContributions': c.numberOfContributions
              })
          .toList()
    });
  }
}
