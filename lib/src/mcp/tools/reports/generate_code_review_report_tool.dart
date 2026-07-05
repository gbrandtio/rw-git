import 'dart:convert';
import '../../../../rw_git.dart';
import '../../../constants.dart';
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
            'description': 'Optional. Branch or commit range to scan for '
                'secrets. Defaults to current HEAD.',
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
    final branch = arguments['branch']?.toString();
    final payload = await ReportOrchestrator(runner).codeReviewReport(
      directory,
      limit: limit,
      branch: branch,
    );
    return jsonEncode(payload.toJson());
  }
}
