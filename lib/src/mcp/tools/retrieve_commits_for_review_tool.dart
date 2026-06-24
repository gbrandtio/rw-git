import '../../../rw_git.dart';

/// retrieve_commits_for_review_tool.dart
/// Retrieves commits formatted into an AI prompt for review.

class RetrieveCommitsForReviewTool implements McpTool {
  final RwGit rwGit;

  RetrieveCommitsForReviewTool(this.rwGit);

  @override
  String get name => 'retrieve_commits_for_ai_review';

  @override
  String get description =>
      'Retrieves recent commits with a structured prompt instructing an AI agent to look for bad commit messages and commented out code.';

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
            'description': 'Number of commits to retrieve (default: 10).'
          }
        },
        'required': ['directory']
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments['directory'] as String;
    final limit = arguments['limit']?.toString() ?? '10';

    final result =
        await rwGit.runCommand(directory, ['log', '-n', limit, '-p']);

    return '''
You are an expert AI code reviewer. Please analyze the following git commits.
I want you to specifically check for:
1. Bad commit messages: look for frustrated, unhelpful, non-detailed, or low-effort messages
(e.g., "fixed stuff", "updates", "todo", "fixme", "do not touch", "argh", "wip").
2. Commented-out code blocks left behind in the diff.
3. Too many changes with a vague or incomplete or inaccurate summary / commit message.

Commits to review:
--------------------------------------------------
$result
--------------------------------------------------
''';
  }
}
