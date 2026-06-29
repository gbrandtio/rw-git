import 'dart:convert';
import '../../../rw_git.dart';
import '../utils/mcp_argument_extensions.dart';

/// init_repository_tool.dart
/// Initializes a new Git repository via MCP.

class InitRepositoryTool implements McpTool {
  final RwGit rwGit;

  InitRepositoryTool(this.rwGit);

  @override
  String get name => 'init_repository';

  @override
  String get description =>
      'Initializes a new Git repository in the specified directory. '
      'For a complete guide on how to use the rw_git MCP tools, invoke the get_rw_git_documentation tool.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'directoryToInit': {
            'type': 'string',
            'description': 'The directory to initialize the git repository in.'
          }
        },
        'required': ['directoryToInit']
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final dir = arguments.getStringArgument('directoryToInit');
    final result = (await rwGit.init(dir)).getOrThrow();
    return jsonEncode({'success': result});
  }
}
