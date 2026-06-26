import '../mcp_tool.dart';

/// get_rw_git_documentation_tool.dart
/// Provides detailed documentation for the RwGit facade out-of-the-box operations and MCP tools.

class GetRwGitDocumentationTool implements McpTool {
  @override
  String get name => 'get_rw_git_documentation';

  @override
  String get description =>
      'Retrieve detailed descriptions and parameter requirements for all RwGit facade out-of-the-box operations and MCP tools. '
      'To invoke this tool, no arguments are required.';

  @override
  Map<String, dynamic> get inputSchema =>
      {'type': 'object', 'properties': {}, 'required': []};

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    return '''
# RwGit Agent Guide & Documentation

⚠️ **IMPORTANT INSTRUCTIONS FOR AI AGENTS**
You are interacting with the RwGit repository via the MCP tools provided in your environment.
- **Do NOT** attempt to run `rw_git` as a CLI command (e.g., `rw_git --help`). It is not an executable in your shell.
- **Do NOT** write scripts (e.g., Python) to manually send JSON-RPC requests to the server process.
- **Do** invoke the provided MCP tools directly using your environment's native tool execution capabilities.

## 1. Raw Git Execution Tool
- **execute_git_command**: Use this to execute raw git commands (e.g., `['log', '-n', '5']`).

## 2. Code Quality Analysis Tools
- **analyze_code_quality**: Use this to get AI-ready metrics on tech debt, suspicious commits, and high-churn files.
- **analyze_code_quality_with_authors**: Similar to the above, but includes author contributions.
- **analyze_release_delta**: Analyzes the difference between two tags to provide a summary of changes, regressions, and code churn.
- **analyze_bus_factor**: Analyzes the repository to identify files that are heavily reliant on a single author.
- **evaluate_comment_llm_generation**: Evaluates code comments based on LLM-generated feedback criteria.
- **evaluate_comment_quality**: Evaluates the quality and professionalism of code comments.
- **evaluate_comment_necessity**: Evaluates whether code comments are necessary or redundant.

## 3. RwGit Facade Tools
The following out-of-the-box Dart facade functions are exposed as individual, strongly-typed MCP tools for your convenience:

- **init_repository**: Initializes a new Git repository.
- **is_git_repository**: Checks if a directory is a valid Git repository.
- **clone_repository**: Clones the remote repository URL into a local directory.
- **checkout_branch**: Checks out the specified branch.
- **fetch_tags**: Fetches all tags from the remote.
- **get_commits_between**: Retrieves all commits between two tags.
- **get_stats**: Retrieves code statistics (insertions, deletions) between two tags.
- **get_contributions_by_author**: Retrieves the shortlog summary of contributions by each author.
- **clone_specific_branch**: Clones the repository and immediately checks out a branch.
- **clone_and_get_statistics**: Clones the repository and then retrieves the statistics between two tags.

## 4. Documentation
- **get_rw_git_documentation**: Returns this guide.
''';
  }
}
