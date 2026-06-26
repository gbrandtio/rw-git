import 'dart:convert';
import '../../../rw_git.dart';

/// is_git_repository_tool.dart
/// Checks if a directory is a valid Git repository via MCP.

class IsGitRepositoryTool implements McpTool {
  final RwGit rwGit;

  IsGitRepositoryTool(this.rwGit);

  @override
  String get name => 'is_git_repository';

  @override
  String get description =>
      'Checks if the specified directory is a valid Git repository. '
      'For a complete guide on how to use the rw_git MCP tools, invoke the get_rw_git_documentation tool.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'directoryToCheck': {
            'type': 'string',
            'description': 'The directory to check.'
          }
        },
        'required': ['directoryToCheck']
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final dir = arguments['directoryToCheck'] as String;
    final result = (await rwGit.isGitRepository(dir)).getOrThrow();
    return jsonEncode({'isGitRepository': result});
  }
}
