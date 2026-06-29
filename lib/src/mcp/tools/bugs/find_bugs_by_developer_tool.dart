import 'dart:convert';
import '../../../../rw_git.dart';
import '../../../constants.dart';
import '../../utils/mcp_argument_extensions.dart';

/// find_bugs_by_developer_tool.dart
/// Implements the MCP Tool to find bugs introduced by a specific developer.
class FindBugsByDeveloperTool implements McpTool {
  final CodeQualityTracker tracker;

  FindBugsByDeveloperTool(this.tracker);

  @override
  String get name => 'find_bugs_by_developer';

  @override
  String get description =>
      'Finds bugs introduced by code written by a specific developer. '
      'It uses the SZZ algorithm to trace bug-fixing commits back to their introducing commits. '
      'Returns the details of the introducing commit alongside the commits that fixed it.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'directory': {
            'type': 'string',
            'description': 'The local repository path.',
          },
          'author': {
            'type': 'string',
            'description': 'The name or email of the developer to analyze.',
          },
          'limit': {
            'type': 'number',
            'description':
                'Maximum number of recent commits to scan for bug fixes (default: $defaultCommitLimit).',
          },
          'positiveRegex': {
            'type': 'string',
            'description':
                'Optional custom regex to identify bug-fixing commits (e.g. "\\b(fix|bug)\\b").',
          },
          'negativeRegex': {
            'type': 'string',
            'description':
                'Optional custom regex to exclude false positive commits (e.g. "\\b(typo|docs)\\b").',
          }
        },
        'required': ['directory', 'author'],
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments.getStringArgument('directory');
    final author = arguments.getStringArgument('author');
    final limit = arguments['limit']?.toString() ?? defaultCommitLimit;
    final positiveRegex = arguments['positiveRegex']?.toString();
    final negativeRegex = arguments['negativeRegex']?.toString();

    final bugs = await tracker.findBugsByDeveloper(
      directory,
      author,
      limit: limit,
      positiveRegex: positiveRegex,
      negativeRegex: negativeRegex,
    );

    return jsonEncode({
      'author_analyzed': author,
      'bugs_introduced_count': bugs.length,
      'bug_introductions': bugs.map((b) => b.toJson()).toList(),
    });
  }
}
