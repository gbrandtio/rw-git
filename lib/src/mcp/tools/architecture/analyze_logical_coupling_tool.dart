import 'dart:convert';
import '../../../../rw_git.dart';
import '../../../constants.dart';
import '../../utils/mcp_argument_extensions.dart';

/// analyze_logical_coupling_tool.dart
/// Implements the MCP Tool to find implicit file dependencies.
class AnalyzeLogicalCouplingTool implements McpTool {
  final ProcessRunner runner;

  AnalyzeLogicalCouplingTool(this.runner);

  @override
  String get name => 'analyze_logical_coupling';

  @override
  String get description =>
      'Analyzes the git repository for logically coupled files (files that frequently change together). '
      'High logical coupling between structurally unrelated files indicates architectural decay or Shotgun Surgery.';

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
          'min_co_changes': {
            'type': 'number',
            'description':
                'Minimum number of times two files must change together to be reported (default: 3).',
          }
        },
        'required': ['directory'],
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments.getStringArgument('directory');
    final limit = arguments['limit']?.toString() ?? defaultCommitLimit;
    final minCoChanges = arguments['min_co_changes'] != null
        ? int.tryParse(arguments['min_co_changes'].toString()) ?? 3
        : 3;

    final algo = LogicalCouplingAlgorithm(runner);
    final results =
        await algo.execute(directory, limit: limit, minCoChanges: minCoChanges);

    return jsonEncode({
      'commits_analyzed': limit,
      'coupled_pairs_found': results.length,
      'logical_coupling': results.map((r) => r.toJson()).toList(),
    });
  }
}
