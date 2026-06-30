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
- **Do NOT** perform any custom git commands for the analysis. You MUST use only the tools and commands offered by rw-git for your analysis.
- **Do** invoke the provided MCP tools directly using your environment's native tool execution capabilities.

## 1. Code Quality Analysis Tools
⚠️ **CRITICAL: Commit Limit (limit argument)**
The default commit analysis limit is 500 commits (`limit = 500`). This is a conservative default for safety and predictability. If your analysis requires a broader historical scope (e.g., analyzing a massive repository's full lifetime) or a tighter, faster analysis window (e.g., checking only the last 10 commits), you **MUST explicitly override the `limit` argument** with the appropriate number of commits.

⚠️ **CRITICAL: Context Offloading (Preventing Overflow)**
To prevent your context window from overflowing, verbose analytical tools offload their massive JSON responses to the local filesystem by default (e.g., `.rw_git/reports/...`) and return only a lightweight summary. **CRITICAL:** You CANNOT generate a meaningful report with just this lightweight summary. You MUST actively read the offloaded JSON file to extract concrete metrics, lists, and actionable insights to include in your final response. For large files, prefer the `read_report_slice` tool (pass the file path, and optionally a dot-separated `path` plus `offset`/`limit`) to fetch only the data you need instead of reading the whole file — the summary's `preview` field (top-level keys, array lengths) tells you what's available to slice. You can specify a custom `output_file` path (must be within the repository) for better organization.

Two ways to skip offloading entirely:
- Responses smaller than 8KB are returned inline automatically — no action needed.
- Pass `return_full_json: true` to force an inline response regardless of size.

**Parameter naming convention:** when a tool exposes a verbose/concise distinction, prefer a `format: "summary" | "full"` parameter for consistency. Existing tools predate this convention and use ad hoc flags instead (`detailed`, `includeCommitLog`, `includeCodeDiff`, `check_freshness`); new tools should follow the `format` convention going forward.

## 2. Available Tools

$toolsMarkdown

## 3. Documentation
- **get_rw_git_documentation**: Returns this guide.
''';
  }
}
