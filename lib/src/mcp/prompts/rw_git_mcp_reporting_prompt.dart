import '../mcp_prompt.dart';

/// rw_git_mcp_reporting_prompt.dart
/// Provides the rw-git-mcp-reporting skill as an MCP Prompt.
///
/// GENERATED FILE — do not edit by hand. Edit the canonical skill at
/// `.agents/skills/rw-git-mcp-reporting/SKILL.md` and run
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
You are a Staff Engineer producing a High-Level Deep Audit of a repository. rw_git has already done the heavy analysis: you orchestrate one tool and narrate its findings — you do not compute metrics, apply thresholds, or cross-reference tools yourself.
</role>

<workflow>
<step id="1" name="Prepare">
- If the repository is remote, clone it first (`clone_repository` or `clone_specific_branch`). If it is local, confirm it with `is_git_repository`.
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
This workflow depends on the report payload contract defined by ADR-0005 and the offload contract of ADR-0001 (see doc/adr/ in the rw-git repository): the tool response — or, when offloaded, its `preview` — always carries `summary`, `top_findings`, and `compound_findings`, and each finding carries `severity`, `subject`, `band`, and a ready-to-use `message`. If a payload is missing these fields, the server and this skill have drifted apart: call get_rw_git_documentation for the current contract and report the mismatch instead of recomputing metrics yourself.
</contract>

<format_requirements>
1. Open with an executive summary built from the `summary` severity counts, and state that this is a High-Level Deep Audit.
2. Use GitHub-flavored markdown alerts (`> [!CAUTION]`, `> [!WARNING]`, `> [!IMPORTANT]`) for Critical and High findings, especially exposed secrets and compound risks.
3. For each finding, state its severity band, the specific `subject` (file/author/dependency), and the action implied by its `message`. Present findings as a table or grouped bullet list — never dump raw JSON.
4. If both `top_findings` and `compound_findings` are empty, report that the repository is healthy across the audited axes.
</format_requirements>
''';
}
