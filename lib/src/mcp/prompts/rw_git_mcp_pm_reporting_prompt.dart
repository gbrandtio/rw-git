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
      'Project-management report on knowledge concentration and delivery bottlenecks using the one-call generate_pm_report tool, which returns already-classified, ranked findings (bus factor, single-owner files, bug hotspots).';

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
You are a Staff Engineer producing a project-management and delivery-risk report for engineering managers. rw_git has already run the analysis and classified every metric — you call one tool and narrate its findings.
</role>

<workflow>
<step id="1" name="Prepare">
- If the repository is remote, clone it first; if local, confirm it with `is_git_repository`.
</step>

<step id="2" name="Generate the report">
- Call `generate_pm_report` with the repository `directory` (and `limit` for a specific commit window).
- The response already contains a `summary` by severity, a ranked `top_findings` array, and a `compound_findings` array. Each finding carries `severity`, `subject`, `band`, `metric`, `value`, and a ready-to-use `message`.
- You do NOT need to read offloaded files or apply bus-factor thresholds — the payload already classified every file/author. If the response was offloaded, narrate from the `preview`'s `top_findings`/`compound_findings`.
- For time-series velocity or release-delta detail, call `analyze_commit_velocity` or `analyze_release_delta` separately.
</step>

<step id="3" name="Report">
- Lead with `compound_findings` and any Critical single-owner or bug-hotspot findings — these are single points of failure.
- Frame each finding for a manager: who/what is the risk, and what staffing or process action it implies.
</step>
</workflow>

<contract>
This workflow depends on the report payload contract defined by ADR-0005 and the offload contract of ADR-0001 (see doc/adr/ in the rw-git repository): the tool response — or, when offloaded, its `preview` — always carries `summary`, `top_findings`, and `compound_findings`, and each finding carries `severity`, `subject`, `band`, and a ready-to-use `message`. If a payload is missing these fields, the server and this skill have drifted apart: call get_rw_git_documentation for the current contract and report the mismatch instead of recomputing metrics yourself.
</contract>

<format_requirements>
1. Open with an executive summary from the `summary` severity counts.
2. Use GitHub-flavored markdown alerts for single-point-of-failure (bus factor) risks.
3. For each finding, state its severity band, the `subject` (person/file/module), and the recommended action. Present as a table or grouped bullets — never dump raw JSON.
4. If both finding lists are empty, report that knowledge and delivery risk are well distributed.
</format_requirements>
''';
}
