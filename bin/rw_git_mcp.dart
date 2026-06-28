import 'package:rw_git/rw_git.dart';
import 'package:rw_git/src/mcp/tools/detect_secrets_tool.dart';
import 'package:rw_git/src/mcp/prompts/rw_git_mcp_reporting_prompt.dart';

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
  registry.registerTool(AnalyzeCodeQualityTool(tracker, rwGit));
  registry.registerTool(AnalyzeCodeQualityWithAuthorsTool(tracker, rwGit));
  registry.registerTool(AnalyzeBugHotspotsTool(tracker));
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

  registry.registerTool(AnalyzeReleaseDeltaTool(rwGit, tracker));
  registry.registerTool(AnalyzeBusFactorTool(tracker, rwGit));
  registry.registerTool(EvaluateCommentLlmGenerationTool(tracker));
  registry.registerTool(EvaluateCommentQualityTool(tracker));
  registry.registerTool(EvaluateCommentNecessityTool(tracker));
  registry.registerTool(DetectSecretsTool(tracker));
  registry.registerTool(AnalyzePrDiffTool(tracker, rwGit));
  registry.registerTool(PredictMergeConflictsTool(tracker));
  registry.registerTool(AnalyzeCommitVelocityTool(tracker));
  registry.registerTool(AnalyzeDependencyDriftTool(tracker));
  registry.registerTool(GenerateChangelogTool(rwGit));
  registry.registerTool(AuditComplianceTool(tracker));
  registry.registerTool(AnalyzeFileOwnershipTool(tracker, rwGit));
  registry.registerTool(AnalyzeDartAstQualityTool(rwGit));
  registry.registerTool(AnalyzeArchitectureDriftTool(rwGit));
  registry.registerTool(AnalyzeCleanCodeTool());

  registry.registerPrompt(RwGitMcpReportingPrompt());

  final server = McpServer(registry: registry);
  server.start();
}
