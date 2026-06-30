import '../../../intelligence/history/heuristics/suspicious_commits_heuristic.dart';
import 'dart:convert';
import '../../../../rw_git.dart';
import '../../../constants.dart';
import '../../utils/mcp_argument_extensions.dart';

/// base_evaluate_comments_tool.dart
/// Abstract base class for tools that evaluate comments
/// in changed code. Returns structured JSON.

abstract class BaseEvaluateCommentsTool implements McpTool {
  final ProcessRunner runner;

  BaseEvaluateCommentsTool(this.runner);

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'directory': {
            'type': 'string',
            'description': 'The local repository path.'
          },
          'limit': {
            'type': 'number',
            'description': 'Number of commits to retrieve for '
                'comment evaluation (default: $defaultCommitLimit).'
          }
        },
        'required': ['directory']
      };

  @override
  Future<String> execute(
    Map<String, dynamic> arguments,
  ) async {
    final directory = arguments.getStringArgument('directory');
    final limit = arguments['limit']?.toString() ?? defaultCommitLimit;

    final changedComments =
        await SuspiciousCommitsHeuristic(runner).extractChangedComments(
      directory,
      limit: limit,
    );

    if (changedComments.isEmpty) {
      return jsonEncode({
        'status': 'no_comments_found',
        'message': 'No comments found in the added/modified '
            'lines for the last $limit commits (excluding doc-only PRs).',
      });
    }

    return jsonEncode({
      'evaluation_criteria': getEvaluationCriteria(),
      'changed_comments': changedComments,
    });
  }

  /// Hook method returning a list of evaluation criteria
  /// strings for the specific comment analysis type.
  List<String> getEvaluationCriteria();
}
