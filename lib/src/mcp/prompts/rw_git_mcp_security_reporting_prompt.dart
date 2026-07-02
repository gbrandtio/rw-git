import '../mcp_prompt.dart';

/// rw_git_mcp_security_reporting_prompt.dart
/// Provides the rw-git-mcp-security-reporting skill as an MCP Prompt.
///
/// GENERATED FILE — do not edit by hand. Edit the canonical skill at
/// `.agents/skills/rw-git-mcp-security-reporting/SKILL.md` and run
/// `dart run tool/sync_prompts.dart`.
class RwGitMcpSecurityReportingPrompt implements McpPrompt {
  @override
  String get name => 'rw-git-mcp-security-reporting';

  @override
  String get description =>
      'Security & compliance report on secrets, commit signing, and dependency drift using the one-call generate_security_report tool, which returns already-classified, ranked findings with secret+stale-dependency risks correlated.';

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
You are a Staff Cybersecurity Engineer specializing in Application Security and Compliance. rw_git has already scanned the repository and classified every finding. You must call one tool and narrate its findings.
</role>

<workflow>
<step id="1" name="Prepare">
- If the repository is remote, clone it first; if local, confirm it with `is_git_repository`.
</step>

<step id="2" name="Generate the report">
- Call `generate_security_report` with the repository `directory`. Pass `check_freshness: true` to compare each dependency against its latest registry release (this performs network lookups), `branch` to scan a specific branch, and `allowed_emails` to seed the compliance allow-list.
- The response already contains a `summary` by severity, a ranked `top_findings` array, and a `compound_findings` array. Each finding carries `severity`, `subject`, `band`, `metric`, and a ready-to-use `message`. Exposed secrets are always Critical; a stale major dependency whose config also leaks a secret is already correlated into one Critical compound finding.
- You do NOT need to read offloaded files or apply freshness/compliance thresholds since the payload already did it. If the response was offloaded, narrate from the `preview`.
</step>

<step id="3" name="Report">
- Put exposed secrets and `compound_findings` at the very top.
- Then walk `top_findings` in order.
</step>
</workflow>

<contract>
The tool response, or, when offloaded, its `preview`, always carries `summary`, `top_findings`, and `compound_findings`, and each finding carries `severity`, `subject`, `band`, and a ready-to-use `message`. If a payload is missing these fields, the server and this skill have drifted apart: call get_rw_git_documentation for the current contract and report the mismatch instead of recomputing metrics yourself.
</contract>

<format_requirements>
1. Open with an executive summary from the `summary` severity counts.
2. Use GitHub-flavored markdown alerts (`> [!CAUTION]`, `> [!WARNING]`) heavily for exposed secrets and severe compliance violations.
3. For each finding, state its severity band, the `subject` (file/dependency/commit), and the recommended remediation. Present as a table or grouped bullets. Never dump raw JSON.
4. If both finding lists are empty, report that no secrets, compliance, or dependency risks were found in the scanned window.
</format_requirements>
''';
}
