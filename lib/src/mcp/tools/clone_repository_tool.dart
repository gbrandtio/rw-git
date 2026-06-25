import 'dart:convert';
import '../../../rw_git.dart';

/// clone_repository_tool.dart
/// Clones a git repository via MCP.

class CloneRepositoryTool implements McpTool {
  final RwGit rwGit;

  CloneRepositoryTool(this.rwGit);

  @override
  String get name => 'clone_repository';

  @override
  String get description =>
      'Clones the remote repository URL into the specified local directory. '
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
          }
        },
        'required': ['localDirectoryToCloneInto', 'repository']
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final localDir = arguments['localDirectoryToCloneInto'] as String;
    final repoUrl = arguments['repository'] as String;
    final result = await rwGit.clone(localDir, repoUrl);
    return jsonEncode({'success': result});
  }
}
