import 'dart:convert';
import '../../../rw_git.dart';
import '../../constants.dart';

/// analyze_bus_factor_tool.dart
/// Analyzes the bus-factor risk and knowledge silos within a git repository.

class AnalyzeBusFactorTool implements McpTool {
  final CodeQualityTracker tracker;
  final RwGit rwGit;

  AnalyzeBusFactorTool(this.tracker, this.rwGit);

  @override
  String get name => 'analyze_bus_factor';

  @override
  String get description =>
      'Analyzes knowledge silos and active maintainership across high-churn areas. '
      'Returns a structured JSON list of files with a high bus-factor risk (e.g., '
      'high churn files predominantly edited by a single author). Set `detailed: true` '
      'to receive the full breakdown of all files. '
      'For a complete guide on how to use the rw_git MCP tools, invoke the get_rw_git_documentation tool.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'directory': {
            'type': 'string',
            'description': 'The local repository path.'
          },
          'limit': {
            'type': 'number',
            'description':
                'Number of commits to analyze (default: $defaultCommitLimit).'
          },
          'detailed': {
            'type': 'boolean',
            'description':
                'If true, returns the author breakdown for all files, not just high-risk ones. Defaults to false.'
          }
        },
        'required': ['directory']
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments['directory'] as String;
    final limit = arguments['limit']?.toString() ?? defaultCommitLimit;
    final detailed = arguments['detailed'] as bool? ?? false;

    final churn =
        await tracker.calculateChurnWithAuthors(directory, limit: limit);

    final List<Map<String, dynamic>> highRiskFiles = [];
    final List<Map<String, dynamic>> allFiles = [];

    // Identify bus factor risk: > 5 changes, and 1 author has > 80% of changes.
    for (final entry in churn.fileChurn.entries) {
      final fileName = entry.key;
      final stats = entry.value;

      final authorsMap = stats.authors.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      if (authorsMap.isEmpty) continue;

      final topAuthor = authorsMap.first;
      final authorshipPercentage = topAuthor.value / stats.total;

      final fileData = {
        'file': fileName,
        'total_changes': stats.total,
        'top_author': topAuthor.key,
        'top_author_percentage': authorshipPercentage,
        'authorship_percentage':
            '${(authorshipPercentage * 100).toStringAsFixed(1)}%',
        'authors_breakdown': stats.authors,
      };

      allFiles.add(fileData);
    } // Close the first loop

    for (final fileData in allFiles) {
      final stats = churn.fileChurn[fileData['file']]!;
      final authorshipPercentage = fileData['top_author_percentage'] as double;

      if (stats.total >= 5 && authorshipPercentage >= 0.8) {
        // Calculate Knowledge Decay (days since last touch by top author)
        final lastTouchRes = await rwGit.runCommand(directory, [
          'log',
          '-1',
          '--format=%aI',
          '--author',
          fileData['top_author'] as String,
          '--',
          fileData['file'] as String,
        ]);

        int knowledgeDecayDays = -1;
        final dateStr = lastTouchRes.getOrNull()?.trim() ?? '';
        if (dateStr.isNotEmpty) {
          final date = DateTime.tryParse(dateStr);
          if (date != null) {
            knowledgeDecayDays = DateTime.now().difference(date).inDays;
          }
        }

        // Calculate Review Coverage (% of commits with Reviewed-by or Co-authored-by)
        final logRes = await rwGit.runCommand(directory, [
          'log',
          '--format=%B',
          '--',
          fileData['file'] as String,
        ]);

        final logText = logRes.getOrNull()?.trim() ?? '';
        final commits = logText.split(RegExp(r'\n(?=commit )'));
        int reviewedCount = 0;

        for (final commitMsg in commits) {
          if (commitMsg.contains('Reviewed-by:') ||
              commitMsg.contains('Co-authored-by:') ||
              commitMsg.contains('Approved-by:')) {
            reviewedCount++;
          }
        }

        final reviewCoverage =
            commits.isEmpty ? 0.0 : reviewedCount / commits.length;

        fileData['knowledge_decay_days'] = knowledgeDecayDays;
        fileData['review_coverage_percentage'] =
            '${(reviewCoverage * 100).toStringAsFixed(1)}%';

        highRiskFiles.add(fileData);
      }
    }

    highRiskFiles.sort((a, b) =>
        (b['total_changes'] as int).compareTo(a['total_changes'] as int));
    allFiles.sort((a, b) =>
        (b['total_changes'] as int).compareTo(a['total_changes'] as int));

    final Map<String, dynamic> response = {
      'total_commits_analyzed': churn.totalCommits,
      'risk_threshold':
          'Files with >= 5 changes and >= 80% authorship by a single developer',
    };

    if (detailed) {
      response['all_files'] = allFiles;
    } else {
      response['high_risk_files'] = highRiskFiles;
    }

    return jsonEncode(response);
  }
}
