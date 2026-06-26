import '../../../rw_git.dart';

/// execute_git_command_tool.dart
/// Executes a raw git command using RwGit.

class ExecuteGitCommandTool implements McpTool {
  final RwGit rwGit;

  ExecuteGitCommandTool(this.rwGit);

  @override
  String get name => 'execute_git_command';

  @override
  String get description =>
      'Execute an arbitrary git command securely. Use this for standard git CLI commands. '
      'To invoke this tool, provide the `directory` (String) and `args` (List<String>). '
      'For a complete guide on how to use the rw_git MCP tools, invoke the get_rw_git_documentation tool.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'directory': {
            'type': 'string',
            'description': 'The local repository path.'
          },
          'args': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Git command arguments (e.g. ["log", "-n", "5"]).'
          }
        },
        'required': ['directory', 'args']
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments['directory'] as String;
    final args = (arguments['args'] as List).cast<String>();

    if (directory.trim().isEmpty) {
      throw ArgumentError('Directory cannot be empty.');
    }
    if (directory.contains('../') || directory.contains('..\\')) {
      throw ArgumentError('Path traversal is not allowed.');
    }

    const blockedCommands = ['push', 'reset', 'clean', 'remote'];
    for (final arg in args) {
      if (blockedCommands.contains(arg)) {
        throw ArgumentError(
            'The git command "$arg" is blocked for security reasons.');
      }
    }

    return (await rwGit.runCommand(directory, args)).getOrThrow();
  }
}
