import '../mcp_prompt.dart';

/// rw_git_mcp_reporting_prompt.dart
/// Provides the rw-git-mcp-reporting skill as an MCP Prompt.
class RwGitMcpReportingPrompt implements McpPrompt {
  @override
  String get name => 'rw-git-mcp-reporting';

  @override
  String get description =>
      'Comprehensive workflow for orchestrating rw_git MCP tools to generate thorough repository reports, code quality assessments, and risk analysis.';

  @override
  List<Map<String, dynamic>> get messages => [
        {
          'role': 'user',
          'content': {
            'type': 'text',
            'text': _promptText,
          }
        }
      ];

  static const String _promptText = r'''
# `rw-git` MCP Reporting Workflow

This skill instructs you on how to orchestrate the MCP analytical tools provided by the `rw_git` server to generate a comprehensive, structured report of the repository.

When a user asks you to analyze the repository, assess code quality, or generate a report, follow this step-by-step workflow.

## 1. Scope Definition (Dynamic Resolution)
Before executing any tools, you **MUST** determine the scope of the analysis based on the user's prompt and current repository context. 
- Ask yourself: Does the user want an analysis of the recent commits? A specific branch comparison (PR)? Or the history between two release tags?
- Resolve the exact arguments you will need (e.g., `limit`, `since`, `until`, `oldVersion`, `newVersion`, `branchA`, `branchB`).
- If the user has not specified a scope, ask for clarification.

## 2. Initial Assessment & Velocity
Gather the high-level overview of code churn, churn rankings, and file risk scores.
- **For Branch/PR Comparisons**: Run `analyze_pr_diff`.
- **For Tag/Release Comparisons**: Run `analyze_release_delta`.
- **For Recent Commits**: Run `analyze_code_quality` (or `analyze_code_quality_with_authors` if the breakdown of contributors is important).
- **Trend Analysis**: Optionally run `analyze_commit_velocity` to gather time-series trend data and detect anomalies in the commit history.

## 3. Security & Compliance Check
Ensure the code being analyzed meets security and project compliance standards.
- Run `detect_secrets_in_commits` to flag any exposed credentials or API keys.
- Run `audit_compliance` to ensure signatures and project commit policies (e.g., no empty messages) are being followed.

## 4. Risk Analysis
Detect architectural bottlenecks, ownership risks, and integration issues.
- Run `analyze_bus_factor` and `analyze_file_ownership` to identify "mega-files" that have drifted in ownership or rely heavily on a single author.
- If you are analyzing a branch intended for integration, run `predict_merge_conflicts` to proactively surface files that will conflict.

## 5. Code Review & Dependency Check
Deep dive into the contents of the changes.
- Use `analyze_dependency_drift` to flag vulnerable, unpinned, or floating dependencies across the ecosystem manifests.
- Evaluate the quality and origin of code comments using `evaluate_comment_quality`, `evaluate_comment_necessity`, and `evaluate_comment_llm_generation`. This helps maintain a clean, self-documenting codebase.

## 6. Release Notes (Optional)
If the user's request involves summarizing changes between releases or summarizing a large feature branch, run `generate_changelog` to retrieve a structured, human-readable list of features, fixes, and breaking changes.

## 7. Synthesis & Formatting
Aggregate the outputs from all the invoked tools into a highly structured, unified Markdown artifact. 
- Present the information with clear executive summaries.
- Use Github-flavored markdown alerts (`> [!WARNING]`, `> [!IMPORTANT]`, etc.) to highlight critical risks, exposed secrets, or severe compliance violations.
- Do not dump raw JSON. Synthesize the metrics into readable tables and actionable insights.

> **Note on Tool Exclusion**: You do NOT need to use low-level setup tools (like `clone_repository`, `checkout_branch`, `execute_git_command`) as part of this reporting orchestration unless explicitly required to prepare the environment first. Focus strictly on the analytical tools listed above.
''';
}
