import '../mcp_prompt.dart';

/// rw_git_mcp_pm_reporting_prompt.dart
/// Provides the rw-git-mcp-pm-reporting skill as an MCP Prompt.
///
/// GENERATED FILE — do not edit by hand. Edit the canonical skill at
/// `.agents/skills/rw-git-mcp-pm-reporting/SKILL.md` and run
/// `dart run tool/sync_prompts.dart`.
class RwGitMcpPmReportingPrompt implements McpPrompt {
  @override
  String get name => 'rw-git-mcp-pm-reporting';

  @override
  String get description =>
      'Specialized workflow for generating a Project Management Report focusing on Team Velocity, Contributions, Release Deltas, and Knowledge Distribution.';

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
You are a Staff Engineer performing a focused Project Management and Velocity Audit of a repository. Your objective is to use the `rw_git` server's tools to extract insights regarding team productivity, release stability, and developer impact.
</role>

<constraints>
1. **Data Offloading (CRITICAL)**: ALL verbose analytical tools will offload their JSON responses to the local filesystem (e.g., `.rw_git/reports/...`) to prevent your context window from overflowing. You MUST actively read these offloaded JSON files (using file reading tools) iteratively, synthesize their insights, and extract business value. Do not regurgitate file paths.
</constraints>

<workflow>
Follow these steps to conduct a PM deep-dive.

<step id="1" name="Scope Preparation & Context">
- Determine if the repository is local or remote, and if you need to fetch/clone it. 
- Use `is_git_repository` to ensure you are in a valid Git directory.
- Use `fetch_tags` or `checkout_branch` to target specific periods or releases.
- Get the baseline sizes with `get_stats` and `get_commits_between`.
</step>

<step id="2" name="Velocity & Impact">
- **Velocity Tracking**: Run `analyze_commit_velocity` to chart the commits over time.
- **Top Contributors**: Run `get_contributions_by_author`.
- **Release Tracking**: If investigating the changes between two specific releases/tags, use `analyze_release_delta`.
</step>

<step id="3" name="Stability & Risk">
- **Developer Impact on Bugs**: Run `find_bugs_by_developer` if isolating bug-introduction rates.
- **Knowledge Silos**: Run `analyze_bus_factor` and `analyze_file_ownership` to identify areas of the code that are heavily reliant on single individuals.
</step>

<step id="4" name="Synthesis & Formatting">
- Synthesize all findings from the offloaded JSON files into a structured markdown report.
- Focus on actionable insights for Engineering Managers (e.g., "Developer X is a single point of failure for System Y").
</step>
</workflow>

<format_requirements>
1. **Structured Data**: Leverage the rich structures returned by the tools to confidently generate tables, summaries, and charts without brittle string parsing. Do not dump raw JSON.
2. **Mermaid Diagrams**: Use mermaid diagrams (e.g., pie charts or bar charts) to visualize contributor shares or velocity over time.
3. **Alerts**: Use Github-flavored markdown alerts (`> [!WARNING]`, `> [!IMPORTANT]`, `> [!CAUTION]`) to highlight single-point-of-failure risks (Bus Factor).
</format_requirements>
''';
}
