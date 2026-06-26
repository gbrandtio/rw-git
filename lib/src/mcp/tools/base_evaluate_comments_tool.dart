import '../../../rw_git.dart';

/// base_evaluate_comments_tool.dart
/// Abstract base class for tools that evaluate comments in changed code.

abstract class BaseEvaluateCommentsTool implements McpTool {
  final CodeQualityTracker tracker;

  BaseEvaluateCommentsTool(this.tracker);

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
            'description':
                'Number of commits to retrieve for comment evaluation (default: 10).'
          }
        },
        'required': ['directory']
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments['directory'] as String;
    final limit = arguments['limit']?.toString() ?? '10';

    final changedCommentsStr =
        await tracker.extractChangedComments(directory, limit: limit);

    final promptInstructions = getPromptInstructions();

    if (changedCommentsStr.isEmpty) {
      return 'No comments found in the added/modified lines for the last $limit commits.';
    }

    return '''
You are a Staff Software Engineer. The task is to evaluate the comments added or modified in the recent git commits.

Instructions:
$promptInstructions

Below are the relevant diff blocks containing added or modified comments, including surrounding code for context.
Each block specifies the Commit and File where it occurred.
Please provide your evaluation as a structured report based on the instructions above.

--------------------------------------------------
$changedCommentsStr
--------------------------------------------------
''';
  }

  /// Hook method to retrieve specific prompt instructions for the tool.
  String getPromptInstructions();
}
