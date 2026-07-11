import 'dart:convert';
import '../../../../rw_git.dart';
import '../../../vcs/git_query.dart';
import '../../utils/mcp_argument_extensions.dart';

/// analyze_architecture_drift_tool.dart
/// Thin MCP wrapper over [ArchitectureDriftAlgorithm] (library-first,
/// ADR-0005): detects architectural drift and tight coupling between the
/// caller's declared logical layers.

class AnalyzeArchitectureDriftTool implements McpTool {
  final GitQuery gitQuery;

  AnalyzeArchitectureDriftTool(this.gitQuery);

  @override
  String get name => 'analyze_architecture_drift';

  @override
  String get description => 'Analyzes git history to detect architectural '
      'drift by identifying commits that modify multiple '
      'independent architectural layers simultaneously, '
      'indicating tight coupling or leaky abstractions. '
      'Returns a list of violating commits and a coupling matrix.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'directory': {
            'type': 'string',
            'description': 'The local repository path.',
          },
          'layer_patterns': {
            'type': 'object',
            'description': 'A map where keys are layer names (e.g., "ui", "data") '
                'and values are regex strings matching file paths for that layer.',
          },
          'since': {
            'type': 'string',
            'description': 'Date string (e.g. "90 days ago").',
          },
        },
        'required': ['directory', 'layer_patterns'],
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments.getStringArgument('directory');
    final layerPatternsMap =
        arguments['layer_patterns'] as Map<String, dynamic>;
    final since = arguments.getOptionalStringArgument('since') ?? '90 days ago';

    final layerRegexes = <String, RegExp>{};
    for (final entry in layerPatternsMap.entries) {
      try {
        layerRegexes[entry.key] = RegExp(entry.value.toString());
      } on FormatException catch (e) {
        return jsonEncode({
          'error': 'Invalid regex pattern for layer "${entry.key}": '
              '${e.message}',
        });
      }
    }

    final ArchitectureDriftDto drift;
    try {
      drift = await ArchitectureDriftAlgorithm(
        gitQuery,
      ).execute(directory, layerRegexes, since: since);
    } on RwGitException catch (e) {
      return jsonEncode({'error': 'Git log failed: ${e.message}'});
    }
    if (drift.totalCommitsAnalyzed == 0) return jsonEncode({'risk': 'none'});

    return jsonEncode({
      'total_commits_analyzed': drift.totalCommitsAnalyzed,
      'commits_with_drift': drift.driftCommits.length,
      'coupling_ratio': double.parse(drift.couplingRatio.toStringAsFixed(3)),
      'coupling_density': double.parse(
        drift.couplingDensity.toStringAsFixed(3),
      ),
      'coupling_matrix': drift.couplingMatrix,
      'architectural_smells':
          drift.smells.map((smell) => smell.toJson()).toList(),
      'drift_commits':
          drift.driftCommits.map((commit) => commit.toJson()).toList(),
    });
  }
}
