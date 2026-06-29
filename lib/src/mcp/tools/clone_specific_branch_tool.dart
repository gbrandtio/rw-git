import 'dart:convert';
import '../../../rw_git.dart';
import '../utils/mcp_argument_extensions.dart';

/// clone_specific_branch_tool.dart
/// Clones a repository and checks out a specific branch via MCP.

class CloneSpecificBranchTool implements McpTool {
  final RwGit rwGit;

  CloneSpecificBranchTool(this.rwGit);

  @override
  String get name => 'clone_specific_branch';

  @override
  String get description =>
      'Clones the remote repository and immediately checks out the specified branch. '
      'For a complete guide on how to use the rw_git MCP tools, invoke the get_rw_git_documentation tool.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'directory': {
            'type': 'string',
            'description': 'The local directory to clone the repository into.'
          },
          'repository': {
            'type': 'string',
            'description': 'The remote repository URL.'
          },
          'branchToCheckout': {
            'type': 'string',
            'description': 'The name of the branch to checkout.'
          }
        },
        'required': ['directory', 'repository', 'branchToCheckout']
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final localDir = arguments.getStringArgument('directory');
    final repoUrl = arguments.getStringArgument('repository');
    final branch = arguments.getStringArgument('branchToCheckout');
    final result = (await rwGit.cloneSpecificBranch(localDir, repoUrl, branch))
        .getOrThrow();
    return jsonEncode({'success': result});
  }
}
