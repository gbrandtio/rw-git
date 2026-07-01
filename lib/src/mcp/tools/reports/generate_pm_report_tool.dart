import 'dart:convert';
import '../../../../rw_git.dart';
import '../../../constants.dart';
import '../../utils/mcp_argument_extensions.dart';

/// generate_pm_report_tool.dart
/// One-call, pre-interpreted project-management report for small/local models.
class GeneratePmReportTool implements McpTool {
  final ProcessRunner runner;

  GeneratePmReportTool(this.runner);

  @override
  String get name => 'generate_pm_report';

  @override
  String get description =>
      'One-call project report: knowledge concentration (bus factor, '
      'single-owner files) and delivery bottlenecks (bug hotspots). Returns '
      'pre-classified, ranked findings to narrate directly.';

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
                'Max recent commits to analyze (default: $defaultCommitLimit).',
          },
        },
        'required': ['directory'],
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments.getStringArgument('directory');
    final limit = arguments['limit']?.toString() ?? defaultCommitLimit;
    final payload =
        await ReportOrchestrator(runner).pmReport(directory, limit: limit);
    return jsonEncode(payload.toJson());
  }
}
