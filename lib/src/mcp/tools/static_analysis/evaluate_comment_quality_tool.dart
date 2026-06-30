import 'base_evaluate_comments_tool.dart';

/// evaluate_comment_quality_tool.dart
/// Evaluates whether comments in changed code are of
/// good quality. Returns structured JSON.

class EvaluateCommentQualityTool extends BaseEvaluateCommentsTool {
  EvaluateCommentQualityTool(super.runner);

  @override
  String get name => 'evaluate_comment_quality';

  @override
  String get description => 'Evaluates whether the comments added or modified '
      'in recent commits are of good quality and follow '
      'clean code practices. Returns structured JSON.';

  @override
  List<String> getEvaluationCriteria() {
    return [
      'Good comments explain "Why" the code is written '
          'a certain way, or detail business logic '
          'constraints, algorithms, or workarounds.',
      'Bad comments explain "What" the code is doing '
          'when the code itself is clear enough.',
      'Check for professionalism: no frustrated language, '
          '"fixme" or "todo" without context, or sloppy '
          'grammar.',
      'For each poor-quality comment, cite the File and '
          'Commit, explain why it is low quality, and '
          'suggest a better alternative if applicable.',
    ];
  }
}
