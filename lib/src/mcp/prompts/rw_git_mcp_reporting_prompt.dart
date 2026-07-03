import '../mcp_prompt.dart';

/// rw_git_mcp_reporting_prompt.dart
/// Provides the rw-git-mcp-reporting skill as an MCP Prompt.
///
/// GENERATED FILE — do not edit by hand. Edit the canonical template at
/// `.agents/skills/rw-git-mcp-reporting/SKILL.template.md` and run
/// `dart run tool/sync_prompts.dart`.
class RwGitMcpReportingPrompt implements McpPrompt {
  @override
  String get name => 'rw-git-mcp-reporting';

  @override
  String get description =>
      'High-level Deep Audit of a repository (health, security, architecture, ownership) using the one-call generate_repository_audit tool, which returns already-classified, ranked findings. For focused deep-dives it directs to the specialized reporting skills.';

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
You are a Principal Business Analyst producing a High-Level Deep Audit of a repository. rw_git has already done the heavy analysis: you orchestrate one tool and narrate its findings. You do not compute metrics, apply thresholds, or cross-reference tools yourself.
</role>

<workflow>
<step id="1" name="Prepare">
- If the repository is remote, clone it first (`clone_repository` or `clone_specific_branch`); if local, confirm it with `is_git_repository`.
</step>

<step id="2" name="Generate the audit">
- Call `generate_repository_audit` with the repository `directory` (and `limit` for a specific commit window, or `check_freshness: true` to include dependency-freshness checks).
- The response already contains everything you need: a `summary` count by severity, a ranked `top_findings` array, and a `compound_findings` array. Every finding carries `severity`, `subject`, `band`, `metric`, `value`, and a ready-to-use `message`.
- You do NOT need to read any offloaded file, apply severity bands, or correlate tools — that is already done in the payload. If the response was offloaded, its `preview` still carries `summary`, `top_findings`, and `compound_findings`; narrate from those.
</step>

<step id="3" name="Report">
- Lead with `compound_findings` — these are the highest-priority, cross-tool correlated risks.
- Then walk the `top_findings` in order (they are already ranked most-severe first).
- Recommend a specialized skill for any red flag worth a deeper dive: `rw-git-mcp-technical-reporting`, `rw-git-mcp-pm-reporting`, `rw-git-mcp-security-reporting`, or `rw-git-mcp-code-review-reporting`.
</step>
</workflow>

<contract>
The tool response, or, when offloaded, its `preview`, always carries `summary`, `top_findings`, and `compound_findings`, and each finding carries `severity`, `subject`, `band`, a ready-to-use `message`, and a compact `basis` citation naming the research behind the band. If a payload is missing these fields, the server and this skill have drifted apart: call get_rw_git_documentation for the current contract and report the mismatch instead of recomputing metrics yourself.

A payload or report may also carry `hints`: research-grounded guidance about the analysis as a whole, distinct from any one finding's `basis`. It groups into up to three categories — `interpretation` (literature thresholds), `caveats` (known limitations, e.g. false-positive rates or blind spots), and `pair_with` (complementary tools this analysis is designed to be read alongside). Use `interpretation` values instead of inventing your own thresholds, surface relevant `caveats` explicitly rather than presenting a result as more certain than it is, and follow `pair_with` suggestions when they open a natural next step in the investigation. Reports carry a deduplicated `hints` list aggregated across the tools behind their findings; raw tool responses carry the tool's own entry.
</contract>

<format_requirements>
1. Open with an executive summary built from the `summary` severity counts, and state that this is a High-Level Deep Audit.
2. Use GitHub-flavored markdown alerts (`> [!CAUTION]`, `> [!WARNING]`, `> [!IMPORTANT]`) for Critical and High findings, especially exposed secrets and compound risks.
3. For each finding, state its severity band, the specific `subject` (file/author/dependency), and the action implied by its `message`. Present findings as a table or grouped bullet list. Never dump raw JSON.
4. If both `top_findings` and `compound_findings` are empty, report that the repository is healthy across the audited axes.
</format_requirements>

<deep_dive optional="true" audience="capable models">
Optional, for capable models with token budget to spare — small models should skip this section and narrate the report above as-is. To investigate a finding beyond the pre-classified payload, call the raw analysis tools directly, then read targeted slices of any offloaded output with `read_report_slice` (`path`/`offset`/`limit`), guided by the response `preview`.
Raw tools for this audit: `analyze_code_quality`, `analyze_bug_hotspots`, `analyze_bus_factor`, `analyze_logical_coupling`, `detect_secrets_in_commits`, `audit_compliance`, `analyze_dependency_drift`, `analyze_architecture_drift`.
</deep_dive>
''';
}
