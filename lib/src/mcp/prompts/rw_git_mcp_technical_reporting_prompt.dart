import '../mcp_prompt.dart';

/// rw_git_mcp_technical_reporting_prompt.dart
/// Provides the rw-git-mcp-technical-reporting skill as an MCP Prompt.
///
/// GENERATED FILE — do not edit by hand. Edit the canonical template at
/// `.agents/skills/rw-git-mcp-technical-reporting/SKILL.template.md` and run
/// `dart run tool/sync_prompts.dart`.
class RwGitMcpTechnicalReportingPrompt implements McpPrompt {
  @override
  String get name => 'rw-git-mcp-technical-reporting';

  @override
  String get description =>
      'Technical report on code quality, technical debt, and architecture using the one-call generate_technical_report tool, which returns already-classified, ranked findings (complexity including genuine McCabe metrics, churn, ownership, bug hotspots, coupling, volatility, refactoring activity).';

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
You are a Staff Enterprise Architect producing a technical quality and architecture report. rw_git has already run the analysis and classified every metric; you call one tool and narrate its findings.
</role>

<workflow>
<step id="1" name="Prepare">
- If the repository is remote, clone it first (`clone_repository` or `clone_specific_branch`); if local, confirm it with `is_git_repository`.
- Use `checkout_branch` if you need a specific branch.
</step>

<step id="2" name="Generate the report">
- Call `generate_technical_report` with the repository `directory` (and `limit` for a specific commit window).
- The response already contains a `summary` by severity, a ranked `top_findings` array, and a `compound_findings` array. Each finding carries `severity`, `subject`, `band`, `metric`, `value`, and a ready-to-use `message`. Complexity findings include genuine McCabe cyclomatic complexity and maintainability index on the highest-churn files; churn explained by refactoring is already discounted.
- You do NOT need to read offloaded files, compare against repo medians, or cross-reference complexity with churn — the payload already did it. If the response was offloaded, narrate from the `preview`'s `top_findings`/`compound_findings`.
</step>

<step id="3" name="Report">
- Lead with `compound_findings` (e.g. a genuine McCabe outlier that also churns heavily is a Critical defect-injection risk).
- Then walk `top_findings` in order. Point directly at the highest-severity files and, where the `message` implies it, propose a concrete refactoring.
</step>
</workflow>

<contract>
The tool response, or, when offloaded, its `preview`, always carries `summary`, `top_findings`, and `compound_findings`, and each finding carries `severity`, `subject`, `band`, a ready-to-use `message`, and a compact `basis` citation naming the research behind the band. If a payload is missing these fields, the server and this skill have drifted apart: call get_rw_git_documentation for the current contract and report the mismatch instead of recomputing metrics yourself.

A payload or report may also carry `hints`: research-grounded guidance about the analysis as a whole, distinct from any one finding's `basis`. It is an object with up to three keys — `interpretation` (literature thresholds), `caveats` (known limitations, e.g. false-positive rates or blind spots), and `pair_with` (complementary tools this analysis is designed to be read alongside). Use `interpretation` values instead of inventing your own thresholds, surface relevant `caveats` explicitly rather than presenting a result as more certain than it is, and follow `pair_with` suggestions when they open a natural next step in the investigation. A raw tool response's `hints` is that one tool's own catalog entry. A report's `hints` aggregates every distinct string from every category, across every tool that fed its findings — deduplicated per category, with nothing capped or dropped, and a `caveats` entry never hides that same tool's `pair_with` suggestion.
</contract>

<format_requirements>
1. Open with an executive summary from the `summary` severity counts.
2. Use GitHub-flavored markdown alerts (`> [!WARNING]`, `> [!CAUTION]`) for Critical/High findings.
3. For each finding, state its severity band, the `subject` file, the metric/`value`, and the recommended action. Present as a table or grouped bullets — never dump raw JSON.
4. If both finding lists are empty, report that the codebase is healthy on the technical axes analysed.
</format_requirements>

<deep_dive optional="true" audience="capable models">
Optional, for capable models with token budget to spare — small models should skip this section and narrate the report above as-is. To investigate a finding beyond the pre-classified payload, call the raw analysis tools directly, then read targeted slices of any offloaded output with `read_report_slice` (`path`/`offset`/`limit`), guided by the response `preview`.
Raw tools for this report: `analyze_code_quality`, `analyze_file_ownership`, `analyze_bug_hotspots`, `analyze_logical_coupling`, `analyze_code_volatility`, `calculate_universal_lexical_metrics`, `analyze_refactoring`.
</deep_dive>
''';
}
