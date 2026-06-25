import 'dart:convert';
import '../../../rw_git.dart';

/// clone_and_get_statistics_tool.dart
/// Clones a repository and gets statistics between two tags via MCP.

class CloneAndGetStatisticsTool implements McpTool {
  final RwGit rwGit;

  CloneAndGetStatisticsTool(this.rwGit);

  @override
  String get name => 'clone_and_get_statistics';

  @override
  String get description =>
      'Clones the specified repository and returns the code statistics between the supplied oldTag and newTag. '
      'For a complete guide on how to use the rw_git MCP tools, invoke the get_rw_git_documentation tool.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'localDirectoryToCloneInto': {
            'type': 'string',
            'description': 'The local directory to clone the repository into.'
          },
          'repository': {
            'type': 'string',
            'description': 'The remote repository URL.'
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
        'required': [
          'localDirectoryToCloneInto',
          'repository',
          'oldTag',
          'newTag'
        ]
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final localDir = arguments['localDirectoryToCloneInto'] as String;
    final repoUrl = arguments['repository'] as String;
    final oldTag = arguments['oldTag'] as String;
    final newTag = arguments['newTag'] as String;
    final stats =
        await rwGit.cloneAndGetStatistics(localDir, repoUrl, oldTag, newTag);
    return jsonEncode({
      'numberOfChangedFiles': stats.numberOfChangedFiles,
      'insertions': stats.insertions,
      'deletions': stats.deletions
    });
  }
}
