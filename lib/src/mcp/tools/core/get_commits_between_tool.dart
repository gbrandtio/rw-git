import 'dart:convert';
import '../../../../rw_git.dart';
import '../../utils/mcp_argument_extensions.dart';

/// get_commits_between_tool.dart
/// Gets commits between two tags via MCP.

class GetCommitsBetweenTool implements McpTool {
  final RwGit rwGit;

  GetCommitsBetweenTool(this.rwGit);

  @override
  String get name => 'get_commits_between';

  @override
  String get description =>
      'Retrieves all commits between two tags in the specified directory. '
      'For a complete guide on how to use the rw_git MCP tools, invoke the get_rw_git_documentation tool.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'directory': {
            'type': 'string',
            'description': 'The local directory containing the git repository.',
          },
          'firstTag': {
            'type': 'string',
            'description': 'The older tag or commit hash.',
          },
          'secondTag': {
            'type': 'string',
            'description': 'The newer tag or commit hash.',
          },
        },
        'required': ['directory', 'firstTag', 'secondTag'],
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final localDir = arguments.getStringArgument('directory');
    final firstTag = arguments.getStringArgument('firstTag');
    final secondTag = arguments.getStringArgument('secondTag');
    final commits = (await rwGit.getCommitsBetween(
      localDir,
      firstTag,
      secondTag,
    ))
        .getOrThrow();
    return jsonEncode({'commits': commits});
  }
}
