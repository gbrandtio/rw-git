import 'base_evaluate_comments_tool.dart';

/// evaluate_comment_quality_tool.dart
/// Tool to evaluate whether comments in the changed code are of good quality.

class EvaluateCommentQualityTool extends BaseEvaluateCommentsTool {
  EvaluateCommentQualityTool(super.tracker);

  @override
  String get name => 'evaluate_comment_quality';

  @override
  String get description =>
      'Evaluates whether the comments added or modified in the recent commits are of good quality and follow clean code practices.';

  @override
  String getPromptInstructions() {
    return '''
1. Evaluate the quality of the provided comments.
2. Good comments should explain "Why" the code is written a certain way, or detail specific business logic constraints, algorithms, or workarounds.
3. Bad comments explain "What" the code is doing when the code itself is clear enough.
4. Check for professionalism (no frustrated language, "fixme", "todo" without context, or sloppy grammar).
5. For each comment with poor quality, cite the File, the Commit, and explain why it is low quality. Provide a better alternative if applicable.
6. If the comments are generally of high quality, state this clearly.
''';
  }
}
