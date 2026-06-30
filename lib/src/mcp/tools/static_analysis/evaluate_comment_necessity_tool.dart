import 'base_evaluate_comments_tool.dart';

/// evaluate_comment_necessity_tool.dart
/// Evaluates whether comments in changed code are
/// actually needed. Returns structured JSON.

class EvaluateCommentNecessityTool extends BaseEvaluateCommentsTool {
  EvaluateCommentNecessityTool(super.runner);

  @override
  String get name => 'evaluate_comment_necessity';

  @override
  String get description => 'Evaluates whether the comments added or modified '
      'in recent commits are actually needed, or if the '
      'code should be refactored to be self-documenting. '
      'Returns structured JSON.';

  @override
  List<String> getEvaluationCriteria() {
    return [
      'The best comment is no comment: code should be '
          'self-documenting through good naming and '
          'clean structure.',
      'Identify comments that merely repeat the code '
          '(e.g., "i++ // increment i" or a doc string '
          'that just restates the method name).',
      'For comments explaining complex logic, consider '
          'if extracting a well-named function or '
          'variable would eliminate the need.',
      'For each unnecessary comment, cite the File and '
          'Commit, and suggest how the code could be '
          'improved to make the comment redundant.',
    ];
  }
}
