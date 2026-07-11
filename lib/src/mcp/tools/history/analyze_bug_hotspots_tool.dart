import 'dart:convert';
import '../../../../rw_git.dart';
import '../../../constants.dart';
import '../../utils/mcp_argument_extensions.dart';

/// analyze_bug_hotspots_tool.dart
/// Implements the refactoring-aware SZZ algorithm (RA-SZZ) to identify files
/// and authors historically responsible for introducing bugs.
class AnalyzeBugHotspotsTool implements McpTool {
  final ProcessRunner runner;

  AnalyzeBugHotspotsTool(this.runner);

  @override
  String get name => 'analyze_bug_hotspots';

  @override
  String get description =>
      'Identifies Bug Hotspots using the refactoring-aware SZZ algorithm '
      '(RA-SZZ). It finds recent bug-fix commits, uses git blame on deleted '
      'lines (excluding refactoring changes) to find the original commit '
      'that introduced the bug, and tracks the files and authors most '
      'responsible for bugs. Use this to flag high-risk files during PR '
      'reviews. Pass `author` to additionally scope the bug-introducing '
      'commits down to a single developer.';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'directory': {
        'type': 'string',
        'description': 'The local repository path.',
      },
      'limit': {
        'type': 'number',
        'description':
            'Maximum number of recent commits to scan for bug fixes (default: $defaultCommitLimit).',
      },
      'author': {
        'type': 'string',
        'description':
            'Optional name or email of a developer. When provided, the '
            'response includes a developer_bug_analysis section listing '
            'only the bugs that developer introduced.',
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
      },
    },
    'required': ['directory'],
  };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments.getStringArgument('directory');
    final limit = arguments['limit']?.toString() ?? defaultCommitLimit;
    final author = arguments.getOptionalStringArgument('author');
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

    final hotspots = BugHotspotsHeuristic().aggregate(matches);

    final sortedFiles =
        hotspots.fileHotspots.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final sortedAuthors =
        hotspots.authorHotspots.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final response = {
      'total_fix_commits_analyzed': hotspots.totalFixCommitsAnalyzed,
      'global_average_bug_lifetime_in_days':
          hotspots.globalAverageBugLifetimeInDays,
      'top_bug_hotspot_files':
          sortedFiles
              .take(15)
              .map(
                (e) => {
                  'file': e.key,
                  'bug_introductions': e.value,
                  'average_bug_lifetime_in_days':
                      hotspots.fileAverageBugLifetimeInDays[e.key] ?? 0.0,
                },
              )
              .toList(),
      'top_bug_hotspot_authors':
          sortedAuthors
              .take(10)
              .map(
                (e) => {
                  'author': e.key,
                  'bug_introductions': e.value,
                  'average_bug_lifetime_in_days':
                      hotspots.authorAverageBugLifetimeInDays[e.key] ?? 0.0,
                },
              )
              .toList(),
    };

    if (author != null) {
      final authorLower = author.toLowerCase();
      final bugs =
          matches
              .where(
                (m) => m.introducingAuthor.toLowerCase().contains(authorLower),
              )
              .toList();

      response['developer_bug_analysis'] = {
        'author_analyzed': author,
        'bugs_introduced_count': bugs.length,
        'bug_introductions':
            bugs
                .map(
                  (b) => {
                    'file': b.filePath,
                    'introducing_commit': b.introducingCommitHash,
                    'fixing_commit': b.fixingCommitHash,
                    // SZZ bug lifetime (introducing commit → fixing commit),
                    // not the effort spent on the fix once the bug was
                    // noticed.
                    'bug_lifetime_in_days': double.parse(
                      (b.fixingDate.difference(b.introducingDate).inMinutes /
                              minutesPerDay)
                          .toStringAsFixed(2),
                    ),
                  },
                )
                .toList(),
      };
    }

    return jsonEncode(response);
  }
}
