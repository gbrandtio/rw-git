import 'dart:convert';
import '../../../rw_git.dart';
import '../utils/mcp_argument_extensions.dart';

/// predict_merge_conflicts_tool.dart
/// Predicts merge conflict risk between two branches.

class PredictMergeConflictsTool implements McpTool {
  final CodeQualityTracker tracker;

  PredictMergeConflictsTool(this.tracker);

  @override
  String get name => 'predict_merge_conflicts';

  @override
  String get description => 'Identifies files modified on both branches since '
      'their merge base to predict potential merge '
      'conflicts before attempting a merge. Returns a '
      'structured JSON list of conflicting files and '
      'files unique to each branch. '
      'For a complete guide, invoke the '
      'get_rw_git_documentation tool.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'directory': {
            'type': 'string',
            'description': 'The local repository path.',
          },
          'branchA': {
            'type': 'string',
            'description': 'The first branch name.',
          },
          'branchB': {
            'type': 'string',
            'description': 'The second branch name.',
          },
        },
        'required': ['directory', 'branchA', 'branchB'],
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments.getStringArgument('directory');
    final branchA = arguments.getStringArgument('branchA');
    final branchB = arguments.getStringArgument('branchB');

    final riskData = await tracker.findConflictRiskFiles(
      directory,
      branchA,
      branchB,
    );

    final conflicting = riskData['conflicting_files'] ?? <String>[];
    final textualConflicts =
        riskData['textual_conflicting_files'] ?? <String>[];
    final onlyA = riskData['files_only_on_a'] ?? <String>[];
    final onlyB = riskData['files_only_on_b'] ?? <String>[];
    final mergeBase = riskData['merge_base']?.firstOrNull ?? '';

    // Classify risk level by file count overlap
    String riskLevel;
    if (conflicting.isEmpty) {
      riskLevel = 'none';
    } else if (conflicting.length <= 3) {
      riskLevel = 'low';
    } else if (conflicting.length <= 10) {
      riskLevel = 'medium';
    } else {
      riskLevel = 'high';
    }

    return jsonEncode({
      'merge_base': mergeBase,
      'risk_level': riskLevel,
      'logical_conflicting_files_count': conflicting.length,
      'logical_conflicting_files': conflicting,
      'textual_conflicting_files_count': textualConflicts.length,
      'textual_conflicting_files': textualConflicts,
      'files_only_on_a': onlyA,
      'files_only_on_b': onlyB,
    });
  }
}
