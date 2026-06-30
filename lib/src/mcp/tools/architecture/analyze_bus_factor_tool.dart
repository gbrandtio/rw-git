import 'dart:convert';
import '../../../../rw_git.dart';
import '../../../constants.dart';
import '../../utils/mcp_argument_extensions.dart';

/// analyze_bus_factor_tool.dart
/// Implements the MCP Tool to calculate the Bus Factor.
class AnalyzeBusFactorTool implements McpTool {
  final ProcessRunner runner;
  final RwGit rwGit;

  AnalyzeBusFactorTool(this.runner, this.rwGit);

  @override
  String get name => 'analyze_bus_factor';

  @override
  String get description =>
      'Calculates the Bus Factor (Truck Factor) for the repository. '
      'This represents the minimum number of key developers whose absence would stall the project, '
      'based on their contribution percentage. Highlights knowledge silos and risk.';

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
          'knowledge_threshold': {
            'type': 'number',
            'description':
                'Percentage of total contributions that defines project dominance (default: 0.50 for 50%).',
          }
        },
        'required': ['directory'],
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments.getStringArgument('directory');
    final limit = arguments['limit']?.toString() ?? defaultCommitLimit;
    final threshold = arguments['knowledge_threshold'] != null
        ? double.tryParse(arguments['knowledge_threshold'].toString()) ?? 0.50
        : 0.50;

    final algo = BusFactorAlgorithm(runner);
    final result = await algo.execute(directory,
        limit: limit, knowledgeThreshold: threshold);

    return jsonEncode(result.toJson());
  }
}
