import 'dart:convert';
import '../../../../rw_git.dart';
import '../../../constants.dart';
import '../../utils/mcp_argument_extensions.dart';

/// analyze_refactoring_tool.dart
/// Implements the MCP Tool to detect structural refactorings.
class AnalyzeRefactoringTool implements McpTool {
  final ProcessRunner runner;

  AnalyzeRefactoringTool(this.runner);

  @override
  String get name => 'analyze_refactoring';

  @override
  String get description =>
      'Detects structural refactorings and code simplifications in the commit history. '
      'Uses a lightweight heuristic approximating RefactoringMiner by tracking file renames (-M), '
      'simplification metrics (high deletion-to-insertion ratio), and semantic commit messages. '
      'Useful for tracking technical debt reduction.';

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
      },
    },
    'required': ['directory'],
  };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments.getStringArgument('directory');
    final limit = arguments['limit']?.toString() ?? defaultCommitLimit;

    final algo = RefactoringDetectionAlgorithm(runner);
    final results = await algo.execute(directory, limit: limit);

    return jsonEncode({
      'commits_analyzed': limit,
      'refactorings_detected': results.length,
      'refactoring_commits': results.map((r) => r.toJson()).toList(),
    });
  }
}
