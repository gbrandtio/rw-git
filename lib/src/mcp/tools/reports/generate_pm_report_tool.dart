import 'dart:convert';
import '../../../../rw_git.dart';
import '../../../constants.dart';
import '../../utils/date_range_validation.dart';
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
          'since': {
            'type': 'string',
            'description': 'Only commits after this date (e.g. '
                '"2024-01-01") — accepts ISO-8601 dates or git relative '
                'phrases (e.g. "6 months ago").',
          },
          'until': {
            'type': 'string',
            'description': 'Only commits before this date (e.g. '
                '"2024-12-31") — accepts ISO-8601 dates or git relative '
                'phrases (e.g. "yesterday").',
          },
        },
        'required': ['directory'],
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments.getStringArgument('directory');
    final limit = arguments['limit']?.toString() ?? defaultCommitLimit;
    final since = arguments.getOptionalStringArgument('since');
    final until = arguments.getOptionalStringArgument('until');

    if (since != null && !isValidDateInput(since)) {
      return jsonEncode({
        'error': 'Invalid "since" value. Use ISO-8601 (e.g. "2024-01-01") '
            'or a git relative date (e.g. "2 weeks ago").',
      });
    }
    if (until != null && !isValidDateInput(until)) {
      return jsonEncode({
        'error': 'Invalid "until" value. Use ISO-8601 (e.g. "2024-12-31") '
            'or a git relative date (e.g. "1 month ago").',
      });
    }

    final payload = await ReportOrchestrator(runner).pmReport(
      directory,
      limit: limit,
      since: since,
      until: until,
    );
    return jsonEncode(payload.toJson());
  }
}
