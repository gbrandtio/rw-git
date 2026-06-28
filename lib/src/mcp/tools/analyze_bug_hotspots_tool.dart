import 'dart:convert';
import '../../../rw_git.dart';

/// analyze_bug_hotspots_tool.dart
/// Implements the SZZ Algorithm to identify files and authors
/// historically responsible for introducing bugs.
class AnalyzeBugHotspotsTool implements McpTool {
  final CodeQualityTracker tracker;

  AnalyzeBugHotspotsTool(this.tracker);

  @override
  String get name => 'analyze_bug_hotspots';

  @override
  String get description => 'Identifies Bug Hotspots using the SZZ algorithm. '
      'It finds recent bug-fix commits, uses git blame on deleted lines '
      'to find the original commit that introduced the bug, and tracks '
      'the files and authors most responsible for bugs. Use this to flag '
      'high-risk files during PR reviews.';

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
                'Maximum number of recent commits to scan for bug fixes (default: 500).',
          }
        },
        'required': ['directory'],
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments['directory'] as String;
    final limit = arguments['limit']?.toString() ?? '500';

    final hotspots =
        await tracker.calculateBugHotspots(directory, limit: limit);

    final sortedFiles = hotspots.fileHotspots.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final sortedAuthors = hotspots.authorHotspots.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return jsonEncode({
      'total_fix_commits_analyzed': hotspots.totalFixCommitsAnalyzed,
      'top_bug_hotspot_files': sortedFiles
          .take(15)
          .map((e) => {'file': e.key, 'bug_introductions': e.value})
          .toList(),
      'top_bug_hotspot_authors': sortedAuthors
          .take(10)
          .map((e) => {'author': e.key, 'bug_introductions': e.value})
          .toList(),
      'analysis_hints': [
        'If a PR modifies a file listed in top_bug_hotspot_files, apply extreme scrutiny, as this file is historically fragile.',
        'If the current author is listed in top_bug_hotspot_authors, ensure they have requested appropriate reviews.',
      ]
    });
  }
}
