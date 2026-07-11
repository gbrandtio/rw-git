import 'dart:convert';
import '../../../../rw_git.dart';
import '../../../constants.dart';
import '../../utils/date_range_validation.dart';
import '../../utils/mcp_argument_extensions.dart';

/// generate_code_review_report_tool.dart
/// One-call, pre-interpreted code-review risk report for small/local models.
class GenerateCodeReviewReportTool implements McpTool {
  final ProcessRunner runner;

  GenerateCodeReviewReportTool(this.runner);

  @override
  String get name => 'generate_code_review_report';

  @override
  String get description =>
      'One-call code-review risk report: secrets, complexity outliers, '
      'single-owner files, bug hotspots in the code under review. Returns '
      'pre-classified, ranked findings.';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'directory': {
        'type': 'string',
        'description': 'The local repository path.',
      },
      'branch': {
        'type': 'string',
        'description':
            'Optional. Branch or commit range to scan for '
            'secrets. Defaults to current HEAD.',
      },
      'limit': {
        'type': 'number',
        'description':
            'Max recent commits to analyze (default: $defaultCommitLimit).',
      },
      'since': {
        'type': 'string',
        'description':
            'Only commits after this date (e.g. '
            '"2024-01-01") — accepts ISO-8601 dates or git relative '
            'phrases (e.g. "6 months ago").',
      },
      'until': {
        'type': 'string',
        'description':
            'Only commits before this date (e.g. '
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
    final branch = arguments['branch']?.toString();
    final since = arguments.getOptionalStringArgument('since');
    final until = arguments.getOptionalStringArgument('until');

    if (since != null && !isValidDateInput(since)) {
      return jsonEncode({
        'error':
            'Invalid "since" value. Use ISO-8601 (e.g. "2024-01-01") '
            'or a git relative date (e.g. "2 weeks ago").',
      });
    }
    if (until != null && !isValidDateInput(until)) {
      return jsonEncode({
        'error':
            'Invalid "until" value. Use ISO-8601 (e.g. "2024-12-31") '
            'or a git relative date (e.g. "1 month ago").',
      });
    }

    final payload = await ReportOrchestrator(runner).codeReviewReport(
      directory,
      limit: limit,
      since: since,
      until: until,
      branch: branch,
    );
    return jsonEncode(payload.toJson());
  }
}
