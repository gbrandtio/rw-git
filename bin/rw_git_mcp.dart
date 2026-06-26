import 'package:rw_git/rw_git.dart';

/// ----------------------------------------------------------------------------
/// rw_git_mcp.dart
/// ----------------------------------------------------------------------------
/// Model Context Protocol (MCP) server for rw_git over standard I/O JSON-RPC.
/// Allows AI agents to interact with git repositories and analyze code quality.

void main() async {
  final runner = ProcessRunner.defaultRunner();
  final rwGit = RwGit(runner: runner);
  final tracker = CodeQualityTracker(runner);

  final registry = McpRegistry();
  registry.registerTool(ExecuteGitCommandTool(rwGit));
  registry.registerTool(AnalyzeCodeQualityTool(tracker, rwGit));
  registry.registerTool(AnalyzeCodeQualityWithAuthorsTool(tracker, rwGit));
  registry.registerTool(GetRwGitDocumentationTool());
  registry.registerTool(InitRepositoryTool(rwGit));
  registry.registerTool(IsGitRepositoryTool(rwGit));
  registry.registerTool(CloneRepositoryTool(rwGit));
  registry.registerTool(CheckoutBranchTool(rwGit));
  registry.registerTool(FetchTagsTool(rwGit));
  registry.registerTool(GetCommitsBetweenTool(rwGit));
  registry.registerTool(GetStatsTool(rwGit));
  registry.registerTool(GetContributionsByAuthorTool(rwGit));
  registry.registerTool(CloneSpecificBranchTool(rwGit));
  registry.registerTool(CloneAndGetStatisticsTool(rwGit));
  registry.registerTool(AnalyzeReleaseDeltaTool(rwGit));
  registry.registerTool(AnalyzeBusFactorTool(tracker, rwGit));
  registry.registerTool(EvaluateCommentLlmGenerationTool(tracker));
  registry.registerTool(EvaluateCommentQualityTool(tracker));
  registry.registerTool(EvaluateCommentNecessityTool(tracker));
  final server = McpServer(registry: registry);
  server.start();
}
