import 'dart:convert';
import '../../../../rw_git.dart';
import '../../utils/date_range_validation.dart';
import '../../utils/mcp_argument_extensions.dart';

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
            'description': 'The local directory containing the git repository.',
          },
          'since': {
            'type': 'string',
            'description': 'Only commits after this date (e.g. '
                '"2024-01-01") — accepts ISO-8601 dates or git relative '
                'phrases (e.g. "6 months ago").',
          },
          'until': {
            'type': 'string',
            'description': 'Only commits before this date (e.g. '
                '"2024-12-31") — accepts ISO-8601 dates or git relative '
                'phrases (e.g. "yesterday").',
          },
        },
        'required': ['directory'],
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final localDir = arguments.getStringArgument('directory');
    final since = arguments.getOptionalStringArgument('since');
    final until = arguments.getOptionalStringArgument('until');

    if (since != null && !isValidDateInput(since)) {
      return jsonEncode({
        'error': 'Invalid "since" value. Use ISO-8601 (e.g. "2024-01-01") '
            'or a git relative date (e.g. "2 weeks ago").',
      });
    }
    if (until != null && !isValidDateInput(until)) {
      return jsonEncode({
        'error': 'Invalid "until" value. Use ISO-8601 (e.g. "2024-12-31") '
            'or a git relative date (e.g. "1 month ago").',
      });
    }

    final contributions = (await rwGit.contributionsByAuthor(
      localDir,
      since: since,
      until: until,
    ))
        .getOrThrow();
    return jsonEncode({
      'contributions': contributions
          .map(
            (c) => {
              'authorName': c.authorName,
              'numberOfContributions': c.numberOfContributions,
            },
          )
          .toList(),
    });
  }
}
