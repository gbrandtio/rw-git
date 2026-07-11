import 'dart:convert';
import '../../../../rw_git.dart';
import '../../../constants.dart';
import '../../utils/mcp_argument_extensions.dart';

/// evaluate_comments_tool.dart
/// Single comment-evaluation tool covering quality, necessity, and
/// LLM-generation in one call (replaces the three former per-aspect tools),
/// shrinking the tool-selection surface a small model must reason over.
class EvaluateCommentsTool implements McpTool {
  final ProcessRunner runner;

  EvaluateCommentsTool(this.runner);

  /// Evaluation criteria per aspect. Selecting a subset via `aspects` returns
  /// only the requested criteria blocks.
  static const Map<String, List<String>> aspectCriteria = {
    'quality': [
      'Good comments explain "Why" the code is written a certain way, or '
          'detail business logic constraints, algorithms, or workarounds.',
      'Bad comments explain "What" the code is doing when the code itself is '
          'clear enough.',
      'Check for professionalism: no frustrated language, "fixme" or "todo" '
          'without context, or sloppy grammar.',
      'For each poor-quality comment, cite the File and Commit, explain why it '
          'is low quality, and suggest a better alternative if applicable.',
    ],
    'necessity': [
      'The best comment is no comment: code should be self-documenting through '
          'good naming and clean structure.',
      'Identify comments that merely repeat the code (e.g., "i++ // increment '
          'i" or a doc string that just restates the method name).',
      'For comments explaining complex logic, consider if extracting a '
          'well-named function or variable would eliminate the need.',
      'For each unnecessary comment, cite the File and Commit, and suggest how '
          'the code could be improved to make the comment redundant.',
    ],
    'llm_generation': [
      'Look for obvious LLM artifacts: <thought> or </thought> tags, phrases '
          'like "Here is the code you requested" or "As an AI language model".',
      'Detect unnaturally verbose or robotic explanations that over-explain '
          'trivial syntax.',
      'Identify comments that hallucinate non-existent features or APIs.',
      'For each comment that appears LLM generated, cite the File and Commit, '
          'and explain why it appears to be AI-generated without human review.',
    ],
  };

  @override
  String get name => 'evaluate_comments';

  @override
  String get description =>
      'Evaluates comments added/modified in recent commits across one or more '
      'aspects: quality (clean-code), necessity (self-documenting), and '
      'llm_generation (AI artifacts). Pass "aspects" to select; defaults to '
      'all. Returns structured JSON.';

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
            'description': 'Number of commits to retrieve for comment '
                'evaluation (default: $defaultCommitLimit).',
          },
          'aspects': {
            'type': 'string',
            'description': 'Optional. Comma-separated aspects to evaluate: '
                'quality, necessity, llm_generation. Defaults to all.',
          },
        },
        'required': ['directory'],
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments.getStringArgument('directory');
    final limit = arguments['limit']?.toString() ?? defaultCommitLimit;
    final requested = _parseAspects(arguments['aspects']?.toString());

    final changedComments = await SuspiciousCommitsHeuristic(
      runner,
    ).extractChangedComments(directory, limit: limit);

    if (changedComments.isEmpty) {
      return jsonEncode({
        'status': 'no_comments_found',
        'message': 'No comments found in the added/modified lines for the last '
            '$limit commits (excluding doc-only PRs).',
      });
    }

    return jsonEncode({
      'aspects': requested,
      'evaluation_criteria': {for (final a in requested) a: aspectCriteria[a]},
      'changed_comments': changedComments,
    });
  }

  List<String> _parseAspects(String? raw) {
    if (raw == null || raw.trim().isEmpty) return aspectCriteria.keys.toList();
    final requested = raw
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where(aspectCriteria.containsKey)
        .toList();
    return requested.isEmpty ? aspectCriteria.keys.toList() : requested;
  }
}
