import 'dart:convert';
import '../../../../rw_git.dart';
import '../../../vcs/git_query.dart';
import '../../utils/mcp_argument_extensions.dart';

/// is_git_repository_tool.dart
/// Checks if a directory is a valid Git repository via MCP.

class IsGitRepositoryTool implements McpTool {
  final RwGit rwGit;
  final GitQuery gitQuery;

  IsGitRepositoryTool(this.rwGit, this.gitQuery);

  @override
  String get name => 'is_git_repository';

  @override
  String get description =>
      'Checks if the specified directory is a valid Git repository, and if so, '
      'returns a Repository Health Dashboard containing basic repository metrics (branch, uncommitted changes, last commit). '
      'For a complete guide on how to use the rw_git MCP tools, invoke the get_rw_git_documentation tool.';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'directory': {'type': 'string', 'description': 'The directory to check.'},
    },
    'required': ['directory'],
  };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final dir = arguments.getStringArgument('directory');
    final result = (await rwGit.isGitRepository(dir)).getOrThrow();

    if (!result) {
      return jsonEncode({'isGitRepository': false});
    }

    // Create Repository Health Dashboard output
    String currentBranch = '';
    bool hasUncommittedChanges = false;
    String lastCommitDate = '';
    int totalCommits = 0;

    try {
      final branchRes =
          (await gitQuery.run(dir, ['branch', '--show-current'])).getOrNull();
      currentBranch = branchRes?.trim() ?? '';

      final statusRes =
          (await gitQuery.run(dir, ['status', '--porcelain'])).getOrNull();
      hasUncommittedChanges =
          (statusRes != null && statusRes.trim().isNotEmpty);

      final logRes =
          (await gitQuery.run(dir, ['log', '-1', '--format=%cd'])).getOrNull();
      lastCommitDate = logRes?.trim() ?? '';

      final countRes =
          (await gitQuery.run(dir, [
            'rev-list',
            '--count',
            'HEAD',
          ])).getOrNull();
      totalCommits = int.tryParse(countRes?.trim() ?? '') ?? 0;
    } catch (_) {
      // Ignore errors if health data cannot be fetched
    }

    return jsonEncode({
      'isGitRepository': true,
      'health_dashboard': {
        'current_branch': currentBranch,
        'has_uncommitted_changes': hasUncommittedChanges,
        'last_commit_date': lastCommitDate,
        'total_commits': totalCommits,
      },
    });
  }
}
