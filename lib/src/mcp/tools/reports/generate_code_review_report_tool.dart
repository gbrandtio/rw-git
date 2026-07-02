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
      'pre-classified, ranked findings. Use analyze_pr_diff / '
      'predict_merge_conflicts for diff-specific detail.';

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
          'base_branch': {
            'type': 'string',
            'description': 'Optional. Merge target branch. When both '
                'base_branch and target_branch are set, predicted merge '
                'conflicts between them are included as findings.',
          },
          'target_branch': {
            'type': 'string',
            'description': 'Optional. Branch under review, compared against '
                'base_branch for conflict prediction.',
          },
        },
        'required': ['directory'],
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments.getStringArgument('directory');
    final limit = arguments['limit']?.toString() ?? defaultCommitLimit;
    final branch = arguments['branch']?.toString();
    final baseBranch = arguments.getOptionalStringArgument('base_branch');
    final targetBranch = arguments.getOptionalStringArgument('target_branch');
    final payload = await ReportOrchestrator(runner).codeReviewReport(
      directory,
      limit: limit,
      branch: branch,
      baseBranch: baseBranch,
      targetBranch: targetBranch,
    );
    return jsonEncode(payload.toJson());
  }
}
