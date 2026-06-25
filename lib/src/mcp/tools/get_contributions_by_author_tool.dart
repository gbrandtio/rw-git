import 'dart:convert';
import '../../../rw_git.dart';

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
          'localCheckoutDirectory': {
            'type': 'string',
            'description': 'The local directory containing the git repository.'
          }
        },
        'required': ['localCheckoutDirectory']
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final localDir = arguments['localCheckoutDirectory'] as String;
    final contributions = await rwGit.contributionsByAuthor(localDir);
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
