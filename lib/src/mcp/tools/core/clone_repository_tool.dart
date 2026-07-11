import 'dart:convert';
import '../../../../rw_git.dart';
import '../../utils/mcp_argument_extensions.dart';

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
      'directory': {
        'type': 'string',
        'description': 'The local directory to clone the repository into.',
      },
      'repository': {
        'type': 'string',
        'description': 'The remote repository URL.',
      },
    },
    'required': ['directory', 'repository'],
  };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final localDir = arguments.getStringArgument('directory');
    final repoUrl = arguments.getStringArgument('repository');
    final result = (await rwGit.clone(localDir, repoUrl)).getOrThrow();
    return jsonEncode({'success': result});
  }
}
