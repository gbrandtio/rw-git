import 'dart:convert';
import '../../../../rw_git.dart';
import '../../../constants.dart';
import '../../utils/mcp_argument_extensions.dart';

/// find_bugs_by_developer_tool.dart
/// Implements the MCP Tool to find bugs introduced by a specific developer.
class FindBugsByDeveloperTool implements McpTool {
  final ProcessRunner runner;

  FindBugsByDeveloperTool(this.runner);

  @override
  String get name => 'find_bugs_by_developer';

  @override
  String get description =>
      'Finds bugs introduced by code written by a specific developer. '
      'It uses the refactoring-aware SZZ algorithm (RA-SZZ) to trace bug-fixing commits back to their introducing commits. '
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
    final positiveRegex = arguments.getOptionalStringArgument('positiveRegex');
    final negativeRegex = arguments.getOptionalStringArgument('negativeRegex');

    if (positiveRegex != null) {
      try {
        RegExp(positiveRegex);
      } on FormatException catch (e) {
        return jsonEncode({
          'error': 'Invalid positiveRegex pattern: ${e.message}',
        });
      }
    }
    if (negativeRegex != null) {
      try {
        RegExp(negativeRegex);
      } on FormatException catch (e) {
        return jsonEncode({
          'error': 'Invalid negativeRegex pattern: ${e.message}',
        });
      }
    }

    final matches = await SzzAlgorithm(runner).execute(
      directory,
      limit: limit,
      positiveRegex: positiveRegex,
      negativeRegex: negativeRegex,
    );

    final authorLower = author.toLowerCase();
    final bugs = matches
        .where((m) => m.introducingAuthor.toLowerCase().contains(authorLower))
        .toList();

    return jsonEncode({
      'author_analyzed': author,
      'bugs_introduced_count': bugs.length,
      'bug_introductions': bugs
          .map((b) => {
                'file': b.filePath,
                'introducing_commit': b.introducingCommitHash,
                'fixing_commit': b.fixingCommitHash,
                // SZZ bug lifetime (introducing commit → fixing commit), not
                // the effort spent on the fix once the bug was noticed.
                'bug_lifetime_in_days': double.parse(
                    (b.fixingDate.difference(b.introducingDate).inMinutes /
                            minutesPerDay)
                        .toStringAsFixed(2)),
              })
          .toList(),
    });
  }
}
