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
  registry.registerTool(
      McpToolFileOffloadDecorator(AnalyzeCodeQualityTool(tracker, rwGit)));
  registry.registerTool(McpToolFileOffloadDecorator(
      AnalyzeCodeQualityWithAuthorsTool(tracker, rwGit)));
  registry.registerTool(
      McpToolFileOffloadDecorator(AnalyzeBugHotspotsTool(tracker)));
  registry.registerTool(GetRwGitDocumentationTool());
  registry.registerTool(InitRepositoryTool(rwGit));
  registry.registerTool(IsGitRepositoryTool(rwGit));
  registry.registerTool(CloneRepositoryTool(rwGit));
  registry.registerTool(CheckoutBranchTool(rwGit));
  registry.registerTool(FetchTagsTool(rwGit));
  registry
      .registerTool(McpToolFileOffloadDecorator(GetCommitsBetweenTool(rwGit)));
  registry.registerTool(GetStatsTool(rwGit));
  registry.registerTool(GetContributionsByAuthorTool(rwGit));
  registry.registerTool(CloneSpecificBranchTool(rwGit));

  registry.registerTool(
      McpToolFileOffloadDecorator(AnalyzeReleaseDeltaTool(rwGit, tracker)));
  registry.registerTool(
      McpToolFileOffloadDecorator(AnalyzeBusFactorTool(tracker, rwGit)));
  registry.registerTool(
      McpToolFileOffloadDecorator(EvaluateCommentLlmGenerationTool(tracker)));
  registry.registerTool(
      McpToolFileOffloadDecorator(EvaluateCommentQualityTool(tracker)));
  registry.registerTool(
      McpToolFileOffloadDecorator(EvaluateCommentNecessityTool(tracker)));
  registry
      .registerTool(McpToolFileOffloadDecorator(DetectSecretsTool(tracker)));
  registry.registerTool(
      McpToolFileOffloadDecorator(AnalyzePrDiffTool(tracker, rwGit)));
  registry.registerTool(
      McpToolFileOffloadDecorator(PredictMergeConflictsTool(tracker)));
  registry.registerTool(
      McpToolFileOffloadDecorator(AnalyzeCommitVelocityTool(tracker)));
  registry.registerTool(
      McpToolFileOffloadDecorator(AnalyzeDependencyDriftTool(tracker)));
  registry
      .registerTool(McpToolFileOffloadDecorator(GenerateChangelogTool(rwGit)));
  registry
      .registerTool(McpToolFileOffloadDecorator(AuditComplianceTool(tracker)));
  registry.registerTool(
      McpToolFileOffloadDecorator(AnalyzeFileOwnershipTool(tracker, rwGit)));
  registry.registerTool(
      McpToolFileOffloadDecorator(AnalyzeDartAstQualityTool(rwGit)));
  registry.registerTool(
      McpToolFileOffloadDecorator(AnalyzeArchitectureDriftTool(rwGit)));
  registry.registerTool(AnalyzeCleanCodeTool());
  registry.registerTool(
      McpToolFileOffloadDecorator(CalculateUniversalLexicalMetricsTool()));

  registry.registerPrompt(RwGitMcpReportingPrompt());

  final server = McpServer(registry: registry);
  server.start();
}
