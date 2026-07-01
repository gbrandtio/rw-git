import '../../mcp_registry.dart';
import '../../mcp_tool.dart';

/// get_rw_git_documentation_tool.dart
/// Provides detailed documentation for the RwGit facade out-of-the-box operations and MCP tools.

class GetRwGitDocumentationTool implements McpTool {
  final McpRegistry registry;

  GetRwGitDocumentationTool(this.registry);
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
    final toolListings = registry.getToolListings();
    final toolsMarkdown = toolListings
        .where((tool) => tool['name'] != 'get_rw_git_documentation')
        .map((tool) => '- **${tool['name']}**: ${tool['description']}')
        .join('\n');

    return '''
# RwGit Agent Guide & Documentation

⚠️ **IMPORTANT INSTRUCTIONS FOR AI AGENTS**
You are interacting with the RwGit repository via the MCP tools provided in your environment.
- **Do NOT** attempt to run `rw_git` as a CLI command (e.g., `rw_git --help`). It is not an executable in your shell.
- **Do NOT** write scripts (e.g., Python) to manually send JSON-RPC requests to the server process.
- **Do NOT** perform any custom git commands for the analysis. You MUST use only the tools offered by rw-git.
- **Do** invoke the provided MCP tools directly using your environment's native tool execution capabilities.

## 1. Recommended: one-call report tools
For most reporting tasks, call ONE of these meta-tools instead of orchestrating many raw tools. Each runs the relevant analyses, applies every severity band and cross-tool compound-risk rule in Dart, and returns a small, ranked, already-classified payload (`summary`, `top_findings`, `compound_findings`) you can narrate directly — no thresholds to apply and, for typical repositories, no offloaded files to read:
- **generate_repository_audit** — high-level deep audit (technical + security)
- **generate_technical_report** — code quality, technical debt, architecture
- **generate_security_report** — secrets, compliance, dependency freshness
- **generate_pm_report** — knowledge concentration & delivery bottlenecks
- **generate_code_review_report** — risk signals for code under review

Every finding already carries `severity`, `subject`, `band`, and `message`. Narrate them; do not recompute metrics or thresholds. Reach for the raw tools below only for targeted deep-dives.

## 2. Raw tool notes
⚠️ **Commit Limit (`limit`)**: the default is 500 commits — override it for a broader or tighter window.

⚠️ **Context Offloading**: verbose raw tools offload large JSON to `.rw_git/reports/...` and return a lightweight summary plus a `preview`. To use their content, read the offloaded file — prefer the `read_report_slice` tool (pass the file path, optionally a dot-separated `path` plus `offset`/`limit`); the `preview` lists what is available to slice. Responses under 8KB return inline automatically; pass `return_full_json: true` to force inline, or `output_file` to choose the path.

## 3. Interpreting raw metrics
The report tools in section 1 apply all severity bands automatically. If you call the raw tools directly, classify their numbers using the bands and the four cross-tool compound-risk rules in **doc/INTERPRETATION_GUIDE.md** (bus factor, bug hotspots, complexity vs repo median, logical coupling, architecture drift, dependency freshness, compliance). Never report a raw metric without stating its severity band.

## 4. Available Tools

$toolsMarkdown

## 5. Documentation
- **get_rw_git_documentation**: Returns this guide.
''';
  }
}
