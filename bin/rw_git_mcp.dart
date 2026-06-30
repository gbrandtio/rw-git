import 'package:rw_git/rw_git.dart';
import 'package:rw_git/src/mcp/tools/security/detect_secrets_tool.dart';
import 'package:rw_git/src/mcp/tools/history/find_bugs_by_developer_tool.dart';
import 'package:rw_git/src/mcp/prompts/rw_git_mcp_reporting_prompt.dart';
import 'package:rw_git/src/mcp/prompts/rw_git_mcp_code_review_reporting_prompt.dart';
import 'package:rw_git/src/mcp/prompts/rw_git_mcp_pm_reporting_prompt.dart';
import 'package:rw_git/src/mcp/prompts/rw_git_mcp_security_reporting_prompt.dart';
import 'package:rw_git/src/mcp/prompts/rw_git_mcp_technical_reporting_prompt.dart';

/// ----------------------------------------------------------------------------
/// rw_git_mcp.dart
/// ----------------------------------------------------------------------------
/// Model Context Protocol (MCP) server for rw_git over standard I/O JSON-RPC.
/// Allows AI agents to interact with git repositories and analyze code quality.

void main() async {
  final runner = ProcessRunner.defaultRunner();
  final rwGit = RwGit(runner: runner);

  final registry = McpRegistry();
  registry.registerTool(
      McpToolFileOffloadDecorator(AnalyzeCodeQualityTool(runner, rwGit)));
  registry.registerTool(McpToolFileOffloadDecorator(
      AnalyzeCodeQualityWithAuthorsTool(runner, rwGit)));
  registry.registerTool(
      McpToolFileOffloadDecorator(AnalyzeBugHotspotsTool(runner)));
  registry.registerTool(
      McpToolFileOffloadDecorator(FindBugsByDeveloperTool(runner)));
  registry.registerTool(GetRwGitDocumentationTool(registry));
  registry.registerTool(InitRepositoryTool(rwGit));
  registry.registerTool(IsGitRepositoryTool(rwGit));
  registry.registerTool(CloneRepositoryTool(rwGit));
  registry.registerTool(CheckoutBranchTool(rwGit));
  registry.registerTool(FetchTagsTool(rwGit));
  registry
      .registerTool(McpToolFileOffloadDecorator(GetCommitsBetweenTool(rwGit)));
  registry.registerTool(McpToolFileOffloadDecorator(GetStatsTool(rwGit)));
  registry.registerTool(
      McpToolFileOffloadDecorator(GetContributionsByAuthorTool(rwGit)));
  registry.registerTool(CloneSpecificBranchTool(rwGit));

  registry.registerTool(
      McpToolFileOffloadDecorator(AnalyzeReleaseDeltaTool(rwGit, runner)));
  registry.registerTool(
      McpToolFileOffloadDecorator(AnalyzeBusFactorTool(runner, rwGit)));
  registry.registerTool(
      McpToolFileOffloadDecorator(AnalyzeLogicalCouplingTool(runner)));
  registry.registerTool(
      McpToolFileOffloadDecorator(AnalyzeCodeVolatilityTool(runner)));
  registry.registerTool(
      McpToolFileOffloadDecorator(AnalyzeRefactoringTool(runner)));
  registry.registerTool(
      McpToolFileOffloadDecorator(EvaluateCommentLlmGenerationTool(runner)));
  registry.registerTool(
      McpToolFileOffloadDecorator(EvaluateCommentQualityTool(runner)));
  registry.registerTool(
      McpToolFileOffloadDecorator(EvaluateCommentNecessityTool(runner)));
  registry.registerTool(McpToolFileOffloadDecorator(DetectSecretsTool(runner)));
  registry.registerTool(
      McpToolFileOffloadDecorator(AnalyzePrDiffTool(runner, rwGit)));
  registry.registerTool(
      McpToolFileOffloadDecorator(PredictMergeConflictsTool(runner)));
  registry.registerTool(
      McpToolFileOffloadDecorator(AnalyzeCommitVelocityTool(runner)));
  registry.registerTool(
      McpToolFileOffloadDecorator(AnalyzeDependencyDriftTool(runner)));
  registry
      .registerTool(McpToolFileOffloadDecorator(GenerateChangelogTool(rwGit)));
  registry
      .registerTool(McpToolFileOffloadDecorator(AuditComplianceTool(runner)));
  registry.registerTool(
      McpToolFileOffloadDecorator(AnalyzeFileOwnershipTool(runner, rwGit)));
  registry.registerTool(
      McpToolFileOffloadDecorator(AnalyzeDartAstQualityTool(rwGit)));
  registry.registerTool(
      McpToolFileOffloadDecorator(AnalyzeArchitectureDriftTool(rwGit)));
  registry.registerTool(McpToolFileOffloadDecorator(AnalyzeCleanCodeTool()));
  registry.registerTool(
      McpToolFileOffloadDecorator(CalculateUniversalLexicalMetricsTool()));

  registry.registerPrompt(RwGitMcpReportingPrompt());
  registry.registerPrompt(RwGitMcpCodeReviewReportingPrompt());
  registry.registerPrompt(RwGitMcpPmReportingPrompt());
  registry.registerPrompt(RwGitMcpSecurityReportingPrompt());
  registry.registerPrompt(RwGitMcpTechnicalReportingPrompt());

  final server = McpServer(registry: registry);
  server.start();
}
