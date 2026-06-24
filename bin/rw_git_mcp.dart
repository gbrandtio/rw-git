import 'package:rw_git/rw_git.dart';
/// ----------------------------------------------------------------------------
/// rw_git_mcp.dart
/// ----------------------------------------------------------------------------
/// Model Context Protocol (MCP) server for rw_git over standard I/O JSON-RPC.
/// Allows AI agents to interact with git repositories and analyze code quality.

void main() async {
  final rwGit = RwGit();
  final tracker = CodeQualityTracker(rwGit.runner);

  final registry = McpRegistry();
  registry.registerTool(ExecuteGitCommandTool(rwGit));
  registry.registerTool(AnalyzeCodeQualityTool(tracker));
  registry.registerTool(AnalyzeCodeQualityWithAuthorsTool(tracker));
  registry.registerTool(RetrieveCommitsForReviewTool(rwGit));
  registry.registerTool(GetRwGitDocumentationTool());

  final server = McpServer(registry: registry);
  server.start();
}
