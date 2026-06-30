import '../mcp_prompt.dart';

/// rw_git_mcp_technical_reporting_prompt.dart
/// Provides the rw-git-mcp-technical-reporting skill as an MCP Prompt.
///
/// GENERATED FILE — do not edit by hand. Edit the canonical skill at
/// `.agents/skills/rw-git-mcp-technical-reporting/SKILL.md` and run
/// `dart run tool/sync_prompts.dart`.
class RwGitMcpTechnicalReportingPrompt implements McpPrompt {
  @override
  String get name => 'rw-git-mcp-technical-reporting';

  @override
  String get description =>
      'Specialized workflow for generating a Technical Report focusing on Code Quality, Technical Debt, and Architectural Integrity.';

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
<role>
You are a Staff Engineer performing a focused Technical Audit of a repository. Your objective is to use the `rw_git` server's deepest analytical tools to extract rich metrics on code quality, identify architectural drift, and locate technical debt and bug hotspots.
</role>

<constraints>
1. **Data Offloading (CRITICAL)**: ALL verbose analytical tools will offload their JSON responses to the local filesystem (e.g., `.rw_git/reports/...`) to prevent your context window from overflowing. You MUST actively read these offloaded JSON files (using file reading tools) iteratively, synthesize their insights, and extract business value. Do not regurgitate file paths.
2. **Commit Limit**: The default limit for repository analysis tools is **500 commits**. Explicitly override the `limit` argument if needed.
</constraints>

<workflow>
Follow these steps to conduct a technical deep-dive.

<step id="1" name="Scope Preparation & Context">
- Determine if the repository is local or remote, and if you need to fetch/clone it. 
- Use `is_git_repository` to ensure you are in a valid Git directory.
- Use `checkout_branch` if you need to target a specific context.
</step>

<step id="2" name="Code Quality & Deep Inspection">
- **Top Debt**: Run `analyze_code_quality` to identify top technical debt candidates.
- **Bug Hotspots**: Run `analyze_bug_hotspots` to see where bugs cluster via SZZ.
- **Universal Metrics**: Run `calculate_universal_lexical_metrics` on critical files identified by the above steps.
- **Clean Code Heuristics**: Run `analyze_clean_code` on the worst-offending files.
- **Logical Coupling**: Run `analyze_logical_coupling` to detect implicitly coupled files.
- **Code Volatility**: Run `analyze_code_volatility` to predict defect-prone files based on churn and unique authors.
- **Refactoring**: Run `analyze_refactoring` to measure technical debt reduction.
- **Dart Specific**: If this is a Dart repository, heavily utilize `analyze_dart_ast_quality`.
</step>

<step id="3" name="Architectural Integrity">
- **Architecture Drift**: Run `analyze_architecture_drift` to detect if boundary layers have eroded over time.
</step>

<step id="4" name="Synthesis & Formatting">
- Synthesize all findings from the offloaded JSON files into a structured markdown report.
- Point the user directly to the files with the highest cyclomatic complexity or the worst maintainability index.
- Propose refactoring strategies.
</step>
</workflow>

<format_requirements>
1. **Structured Data**: Leverage the rich structures returned by the tools to confidently generate tables, summaries, and charts without brittle string parsing. Do not dump raw JSON.
2. **Mermaid Diagrams**: Use mermaid diagrams to visualize complex architectural drift relationships or hotspots.
3. **Alerts**: Use Github-flavored markdown alerts (`> [!WARNING]`, `> [!IMPORTANT]`, `> [!CAUTION]`) to highlight the most egregious technical debt.
</format_requirements>
''';
}
