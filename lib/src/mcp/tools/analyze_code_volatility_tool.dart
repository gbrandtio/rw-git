import 'dart:convert';
import '../../../rw_git.dart';
import '../../constants.dart';
import '../utils/mcp_argument_extensions.dart';
import '../../quality/code_volatility_algorithm.dart';

/// analyze_code_volatility_tool.dart
/// Implements the MCP Tool to calculate defect-prone files via code volatility.
class AnalyzeCodeVolatilityTool implements McpTool {
  final CodeQualityTracker tracker;

  AnalyzeCodeVolatilityTool(this.tracker);

  @override
  String get name => 'analyze_code_volatility';

  @override
  String get description =>
      'Predicts defect-prone files based on historical code churn and author count. '
      'Files with high volatility (changed frequently by many different developers) '
      'are statistically more likely to contain bugs.';

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
                'Maximum number of recent commits to analyze (default: $defaultCommitLimit).',
          }
        },
        'required': ['directory'],
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments.getStringArgument('directory');
    final limit = arguments['limit']?.toString() ?? defaultCommitLimit;

    final algo = CodeVolatilityAlgorithm(tracker.runner);
    final results = await algo.execute(directory, limit: limit);

    // Limit output to top 50 most volatile files to prevent massive JSON payloads
    final topResults = results.take(50).map((r) => r.toJson()).toList();

    return jsonEncode({
      'commits_analyzed': limit,
      'highly_volatile_files_found': topResults.length,
      'top_volatile_files': topResults,
    });
  }
}
