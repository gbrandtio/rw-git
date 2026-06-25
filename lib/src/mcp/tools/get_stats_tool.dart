import 'dart:convert';
import '../../../rw_git.dart';

/// get_stats_tool.dart
/// Gets statistics between two tags via MCP.

class GetStatsTool implements McpTool {
  final RwGit rwGit;

  GetStatsTool(this.rwGit);

  @override
  String get name => 'get_stats';

  @override
  String get description =>
      'Retrieves code statistics (insertions, deletions, files changed) between two tags. '
      'For a complete guide on how to use the rw_git MCP tools, invoke the get_rw_git_documentation tool.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'localCheckoutDirectory': {
            'type': 'string',
            'description': 'The local directory containing the git repository.'
          },
          'oldTag': {
            'type': 'string',
            'description': 'The older tag or commit hash.'
          },
          'newTag': {
            'type': 'string',
            'description': 'The newer tag or commit hash.'
          }
        },
        'required': ['localCheckoutDirectory', 'oldTag', 'newTag']
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final localDir = arguments['localCheckoutDirectory'] as String;
    final oldTag = arguments['oldTag'] as String;
    final newTag = arguments['newTag'] as String;
    final stats = await rwGit.stats(localDir, oldTag, newTag);
    return jsonEncode({
      'numberOfChangedFiles': stats.numberOfChangedFiles,
      'insertions': stats.insertions,
      'deletions': stats.deletions
    });
  }
}
