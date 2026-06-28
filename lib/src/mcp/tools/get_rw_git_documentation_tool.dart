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
- **Do NOT** perform any custom git commands for the analysis. You MUST use only the tools and commands offered by rw-git for your analysis.
- **Do** invoke the provided MCP tools directly using your environment's native tool execution capabilities.

## 1. Code Quality Analysis Tools
These tools return structured JSON metrics.
- **analyze_code_quality**: Use this to get JSON metrics on tech debt, suspicious commits, and high-churn files. Use `includeCodeDiff: true` to inject actual source code diffs for LLM code-smell analysis.
- **analyze_code_quality_with_authors**: Similar to the above, but includes author contributions. Also supports `includeCodeDiff: true`.
- **analyze_release_delta**: Analyzes the difference between two tags to provide a JSON summary of changes, regressions, and code churn.
- **analyze_bus_factor**: Analyzes the repository to identify files that are heavily reliant on a single author.
- **evaluate_comment_llm_generation**: Evaluates code comments based on LLM-generated feedback criteria.
- **evaluate_comment_quality**: Evaluates the quality and professionalism of code comments.
- **evaluate_comment_necessity**: Evaluates whether code comments are necessary or redundant.
- **detect_secrets_in_commits**: Scans commit history for exposed secrets, API keys, or credentials. Returns a list of detected secrets with commit hashes and file names.

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


## 4. Documentation
- **get_rw_git_documentation**: Returns this guide.

## 5. Advanced Analysis Tools
- **analyze_pr_diff**: Analyzes a PR diff (base..head) for risk signals. Returns per-file risk scores from churn history, bus factor, and secret detection. Use `topN` to limit output.
- **predict_merge_conflicts**: Identifies files modified on both branches since their merge base to predict merge conflicts before attempting a merge.
- **analyze_commit_velocity**: Computes commit velocity bucketed by day/week/month. Returns time-series data with per-author breakdown, trend analysis (accelerating/decelerating/stable), and anomaly detection.
- **analyze_dependency_drift**: Parses dependency manifests (pubspec.yaml, package.json, requirements.txt, go.mod, Cargo.toml, Gemfile) for pinned vs floating version analysis and lock file presence.
- **generate_changelog**: Generates a structured changelog between two tags/commits using Conventional Commits conventions (feat/fix/BREAKING CHANGE). Also performs structural impact analysis using SZZ algorithm to link fixes to bug-introducing commits.
- **audit_compliance**: Scans commit history for unsigned commits, empty messages, PR size violations, and unrecognized author emails. Supply `allowedEmails` to flag unknown contributors.
- **analyze_file_ownership**: Cross-references CODEOWNERS with git blame history to detect ownership drift and unowned files.
- **analyze_dart_ast_quality**: Performs deep AST-level analysis of Dart files. Returns a dependency graph, semantic signature diff, and dead code audit for the touched files. 
- **analyze_architecture_drift**: Analyzes git history to detect architectural drift by identifying commits that modify multiple independent architectural layers simultaneously.
- **analyze_clean_code**: Language-agnostic tool to analyze basic clean code heuristics of a specific file. Detects excessive length, deep nesting, and long lines.
''';
  }
}
