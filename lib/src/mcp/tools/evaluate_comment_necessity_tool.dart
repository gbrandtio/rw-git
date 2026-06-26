import 'base_evaluate_comments_tool.dart';

/// evaluate_comment_necessity_tool.dart
/// Tool to evaluate whether comments in the changed code are actually needed.

class EvaluateCommentNecessityTool extends BaseEvaluateCommentsTool {
  EvaluateCommentNecessityTool(super.tracker);

  @override
  String get name => 'evaluate_comment_necessity';

  @override
  String get description =>
      'Evaluates whether the comments added or modified in the recent commits are actually needed, or if the code should be refactored to be self-documenting.';

  @override
  String getPromptInstructions() {
    return '''
1. Evaluate whether each of the provided comments is truly necessary.
2. The best comment is no comment—code should ideally be self-documenting through good naming (variables, functions, classes) and clean structure.
3. Identify comments that merely repeat the code (e.g., `i++ // increment i`, or a doc string that just repeats the method name).
4. For comments that explain complex logic, consider if extracting a well-named function or variable would eliminate the need for the comment.
5. For each unnecessary comment, cite the File, the Commit, and suggest how the code could be improved to make the comment redundant.
6. If all comments are justified, state that they add necessary value.
''';
  }
}
