import 'dart:convert';
import '../../../../rw_git.dart';
import '../../../constants.dart';
import '../../utils/mcp_argument_extensions.dart';

/// generate_technical_report_tool.dart
/// One-call, pre-interpreted technical report for small/local models.
class GenerateTechnicalReportTool implements McpTool {
  final ProcessRunner runner;

  GenerateTechnicalReportTool(this.runner);

  @override
  String get name => 'generate_technical_report';

  @override
  String get description =>
      'One-call technical report: complexity, churn, ownership, bug hotspots, '
      'coupling, volatility. Returns pre-classified, ranked findings '
      '(top_findings/compound_findings) to narrate directly — no thresholds or '
      'joins to apply.';

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
    final payload = await ReportOrchestrator(runner)
        .technicalReport(directory, limit: limit);
    return jsonEncode(payload.toJson());
  }
}
