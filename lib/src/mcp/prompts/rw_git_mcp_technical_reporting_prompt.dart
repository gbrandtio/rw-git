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
      'Technical report on code quality, technical debt, and architecture using the one-call generate_technical_report tool, which returns already-classified, ranked findings (complexity, churn, ownership, bug hotspots, coupling, volatility).';

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
You are a Staff Engineer producing a technical quality and architecture report. rw_git has already run the analysis and classified every metric — you call one tool and narrate its findings.
</role>

<workflow>
<step id="1" name="Prepare">
- If the repository is remote, clone it first; if local, confirm it with `is_git_repository`. Use `checkout_branch` if you need a specific branch.
</step>

<step id="2" name="Generate the report">
- Call `generate_technical_report` with the repository `directory` (and `limit` for a specific commit window).
- The response already contains a `summary` by severity, a ranked `top_findings` array, and a `compound_findings` array. Each finding carries `severity`, `subject`, `band`, `metric`, `value`, and a ready-to-use `message`.
- You do NOT need to read offloaded files, compare against repo medians, or cross-reference complexity with churn — the payload already did it. If the response was offloaded, narrate from the `preview`'s `top_findings`/`compound_findings`.
</step>

<step id="3" name="Report">
- Lead with `compound_findings` (e.g. a complexity outlier that also churns heavily is a Critical defect-injection risk).
- Then walk `top_findings` in order. Point directly at the highest-severity files and, where the `message` implies it, propose a concrete refactoring.
</step>
</workflow>

<format_requirements>
1. Open with an executive summary from the `summary` severity counts.
2. Use GitHub-flavored markdown alerts (`> [!WARNING]`, `> [!CAUTION]`) for Critical/High findings.
3. For each finding, state its severity band, the `subject` file, the metric/`value`, and the recommended action. Present as a table or grouped bullets — never dump raw JSON.
4. If both finding lists are empty, report that the codebase is healthy on the technical axes analysed.
</format_requirements>
''';
}
