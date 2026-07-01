import '../core/process_runner.dart';
import '../vcs/rw_git_facade.dart';
import 'mcp_registry.dart';
import 'mcp_tool.dart';
import 'mcp_tool_file_offload_decorator.dart';
import 'mcp_tool_metadata_decorator.dart';

import 'tools/static_analysis/analyze_code_quality_tool.dart';
import 'tools/history/analyze_bug_hotspots_tool.dart';
import 'tools/history/find_bugs_by_developer_tool.dart';
import 'tools/system/get_rw_git_documentation_tool.dart';
import 'tools/system/read_report_slice_tool.dart';
import 'tools/core/init_repository_tool.dart';
import 'tools/core/is_git_repository_tool.dart';
import 'tools/core/clone_repository_tool.dart';
import 'tools/core/checkout_branch_tool.dart';
import 'tools/core/fetch_tags_tool.dart';
import 'tools/core/get_commits_between_tool.dart';
import 'tools/history/get_stats_tool.dart';
import 'tools/history/get_contributions_by_author_tool.dart';
import 'tools/core/clone_specific_branch_tool.dart';
import 'tools/history/analyze_release_delta_tool.dart';
import 'tools/architecture/analyze_bus_factor_tool.dart';
import 'tools/architecture/analyze_logical_coupling_tool.dart';
import 'tools/history/analyze_code_volatility_tool.dart';
import 'tools/architecture/analyze_refactoring_tool.dart';
import 'tools/static_analysis/evaluate_comments_tool.dart';
import 'tools/security/detect_secrets_tool.dart';
import 'tools/history/analyze_pr_diff_tool.dart';
import 'tools/history/predict_merge_conflicts_tool.dart';
import 'tools/history/analyze_commit_velocity_tool.dart';
import 'tools/architecture/analyze_dependency_drift_tool.dart';
import 'tools/history/generate_changelog_tool.dart';
import 'tools/security/audit_compliance_tool.dart';
import 'tools/architecture/analyze_file_ownership_tool.dart';
import 'tools/static_analysis/analyze_dart_ast_quality_tool.dart';
import 'tools/architecture/analyze_architecture_drift_tool.dart';
import 'tools/static_analysis/analyze_clean_code_tool.dart';
import 'tools/static_analysis/calculate_universal_lexical_metrics_tool.dart';
import 'tools/reports/generate_technical_report_tool.dart';
import 'tools/reports/generate_security_report_tool.dart';
import 'tools/reports/generate_pm_report_tool.dart';
import 'tools/reports/generate_code_review_report_tool.dart';
import 'tools/reports/generate_repository_audit_tool.dart';

import 'prompts/rw_git_mcp_reporting_prompt.dart';
import 'prompts/rw_git_mcp_code_review_reporting_prompt.dart';
import 'prompts/rw_git_mcp_pm_reporting_prompt.dart';
import 'prompts/rw_git_mcp_security_reporting_prompt.dart';
import 'prompts/rw_git_mcp_technical_reporting_prompt.dart';

/// server_registry.dart
///
/// Single source of truth for the set of MCP tools and prompts the rw_git
/// server exposes. Both the `rw_git_mcp` executable and the test suite build
/// the registry through [buildDefaultRegistry] so the wired-up surface can
/// never drift between production and tests.
/// Read-only analysis tools never mutate the repository and are safe to repeat,
/// so clients may auto-approve them.
const Map<String, dynamic> _readOnly = {
  'readOnlyHint': true,
  'idempotentHint': true,
};

/// Tools that change repository or working-tree state (clone, checkout, init,
/// fetch). Advertised so clients know they are not safe to auto-run.
const Map<String, dynamic> _mutating = {'readOnlyHint': false};

/// Shared, compact output shape for the one-call report meta-tools. Advertised
/// so a model knows the payload structure — pre-classified, ranked findings —
/// without reading anything first.
const Map<String, dynamic> _reportOutputSchema = {
  'type': 'object',
  'properties': {
    'report_type': {'type': 'string'},
    'summary': {'type': 'object'},
    'top_findings': {'type': 'array'},
    'compound_findings': {'type': 'array'},
  },
};

McpRegistry buildDefaultRegistry({ProcessRunner? runner, RwGit? rwGit}) {
  final r = runner ?? ProcessRunner.defaultRunner();
  final git = rwGit ?? RwGit(runner: r);

  final registry = McpRegistry();

  // Read-only analysis tools (offloaded), with standard annotations attached
  // as the outermost wrapper so the registry can advertise them.
  void ro(McpTool tool, {Map<String, dynamic>? outputSchema}) =>
      registry.registerTool(McpToolWithMetadata(tool,
          annotations: _readOnly, outputSchema: outputSchema));

  void offloadedRo(McpTool inner, {Map<String, dynamic>? outputSchema}) =>
      ro(McpToolFileOffloadDecorator(inner, resources: registry.resources),
          outputSchema: outputSchema);

  void mutating(McpTool tool) =>
      registry.registerTool(McpToolWithMetadata(tool, annotations: _mutating));

  // One-call, pre-interpreted report meta-tools. Registered first so they are
  // the prominent choice for small models: a single call returns a complete,
  // band-classified, ranked report instead of forcing the model to orchestrate
  // many raw tools, read offloaded files, and apply the interpretation guide
  // itself.
  offloadedRo(GenerateRepositoryAuditTool(r),
      outputSchema: _reportOutputSchema);
  offloadedRo(GenerateTechnicalReportTool(r),
      outputSchema: _reportOutputSchema);
  offloadedRo(GenerateSecurityReportTool(r), outputSchema: _reportOutputSchema);
  offloadedRo(GeneratePmReportTool(r), outputSchema: _reportOutputSchema);
  offloadedRo(GenerateCodeReviewReportTool(r),
      outputSchema: _reportOutputSchema);

  offloadedRo(AnalyzeCodeQualityTool(r, git));
  offloadedRo(AnalyzeBugHotspotsTool(r));
  offloadedRo(FindBugsByDeveloperTool(r));
  ro(GetRwGitDocumentationTool(registry));
  ro(ReadReportSliceTool());
  mutating(InitRepositoryTool(git));
  ro(IsGitRepositoryTool(git));
  mutating(CloneRepositoryTool(git));
  mutating(CheckoutBranchTool(git));
  mutating(FetchTagsTool(git));
  offloadedRo(GetCommitsBetweenTool(git));
  offloadedRo(GetStatsTool(git));
  offloadedRo(GetContributionsByAuthorTool(git));
  mutating(CloneSpecificBranchTool(git));
  offloadedRo(AnalyzeReleaseDeltaTool(git, r));
  // Stable, compact shape — advertised so the model knows the offloaded file's
  // structure without reading it. Additional tools can opt in the same way.
  offloadedRo(AnalyzeBusFactorTool(r, git), outputSchema: const {
    'type': 'object',
    'properties': {
      'bus_factor': {'type': 'integer'},
      'total_developers_analyzed': {'type': 'integer'},
      'top_contributors': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'author': {'type': 'string'},
            'contributions': {'type': 'integer'},
            'percentage': {'type': 'string'},
          },
        },
      },
    },
  });
  offloadedRo(AnalyzeLogicalCouplingTool(r));
  offloadedRo(AnalyzeCodeVolatilityTool(r));
  offloadedRo(AnalyzeRefactoringTool(r));
  offloadedRo(EvaluateCommentsTool(r));
  offloadedRo(DetectSecretsTool(r));
  offloadedRo(AnalyzePrDiffTool(r, git));
  offloadedRo(PredictMergeConflictsTool(r));
  offloadedRo(AnalyzeCommitVelocityTool(r));
  offloadedRo(AnalyzeDependencyDriftTool(r));
  offloadedRo(GenerateChangelogTool(git));
  offloadedRo(AuditComplianceTool(r));
  offloadedRo(AnalyzeFileOwnershipTool(r, git));
  offloadedRo(AnalyzeDartAstQualityTool(git));
  offloadedRo(AnalyzeArchitectureDriftTool(git));
  offloadedRo(AnalyzeCleanCodeTool());
  offloadedRo(CalculateUniversalLexicalMetricsTool());

  registry.registerPrompt(RwGitMcpReportingPrompt());
  registry.registerPrompt(RwGitMcpCodeReviewReportingPrompt());
  registry.registerPrompt(RwGitMcpPmReportingPrompt());
  registry.registerPrompt(RwGitMcpSecurityReportingPrompt());
  registry.registerPrompt(RwGitMcpTechnicalReportingPrompt());

  return registry;
}
