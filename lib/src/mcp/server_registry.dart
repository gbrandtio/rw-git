import '../constants.dart';
import '../core/process_runner.dart';
import '../intelligence/history/algorithms/szz_algorithm.dart';
import '../intelligence/interpretation/tool_hints_catalog.dart';
import '../vcs/git_query.dart';
import '../vcs/rw_git_facade.dart';
import 'mcp_registry.dart';
import 'mcp_tool.dart';
import 'mcp_tool_file_offload_decorator.dart';
import 'mcp_tool_hints_decorator.dart';
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

/// Shared by the mutating tools that only report whether the underlying git
/// operation succeeded.
const Map<String, dynamic> _successOutputSchema = {
  'type': 'object',
  'properties': {
    'success': {'type': 'boolean'},
  },
};

McpRegistry buildDefaultRegistry({ProcessRunner? runner, RwGit? rwGit}) {
  final processRunner = runner ?? ProcessRunner.defaultRunner();
  final git = rwGit ?? RwGit(runner: processRunner);
  final gitQuery = ReadOnlyGitQuery(processRunner);

  final registry = McpRegistry();

  // Read-only analysis tools (offloaded), with standard annotations attached
  // as the outermost wrapper so the registry can advertise them.
  void registerReadOnly(McpTool tool, {Map<String, dynamic>? outputSchema}) =>
      registry.registerTool(McpToolWithMetadata(tool,
          annotations: _readOnly, outputSchema: outputSchema));

  // Splices research-grounded ToolHints into a tool's payload when the
  // catalog has an entry for it; a no-op passthrough otherwise. Applied
  // before offloading so hints ride in inline responses, persist into the
  // offloaded full file, and remain visible to the preview builder.
  McpTool withHints(McpTool inner) => toolHintsCatalog.containsKey(inner.name)
      ? McpToolHintsDecorator(inner)
      : inner;

  void offloadedRo(McpTool inner, {Map<String, dynamic>? outputSchema}) =>
      registerReadOnly(
          McpToolFileOffloadDecorator(withHints(inner),
              resources: registry.resources,
              // Per-tool size gate (ADR-0011); global default when unlisted.
              offloadThresholdBytes: perToolOffloadThresholdBytes[inner.name] ??
                  offloadSizeThresholdBytes),
          outputSchema: outputSchema);

  void mutating(McpTool tool, {Map<String, dynamic>? outputSchema}) =>
      registry.registerTool(McpToolWithMetadata(tool,
          annotations: _mutating, outputSchema: outputSchema));

  // One-call, pre-interpreted report meta-tools. Registered first so they are
  // the prominent choice for small models: a single call returns a complete,
  // band-classified, ranked report instead of forcing the model to orchestrate
  // many raw tools, read offloaded files, and apply the interpretation guide
  // itself. Registration order is a deliberate discoverability ranking
  // (ADR-0009): report tools must stay at the top of tools/list; do not
  // reorder alphabetically or append new tools blindly.
  offloadedRo(GenerateRepositoryAuditTool(processRunner),
      outputSchema: _reportOutputSchema);
  offloadedRo(GenerateTechnicalReportTool(processRunner),
      outputSchema: _reportOutputSchema);
  offloadedRo(GenerateSecurityReportTool(processRunner),
      outputSchema: _reportOutputSchema);
  offloadedRo(GeneratePmReportTool(processRunner),
      outputSchema: _reportOutputSchema);
  offloadedRo(GenerateCodeReviewReportTool(processRunner),
      outputSchema: _reportOutputSchema);

  // outputSchema policy (ADR-0013): a schema is advertised only where the
  // shape is stable, compact, and drives `structuredContent` — the report
  // meta-tools, tiny git-operation results, and a handful of fixed-shape
  // tools. Every schema byte is a fixed cost each conversation pays in
  // tools/list (budget enforced by test/mcp/tools_list_size_test.dart), so
  // broad-but-shallow schemas that merely enumerate top-level keys are
  // deliberately not advertised; the offload `preview` already conveys that
  // structure at response time for free.
  offloadedRo(AnalyzeCodeQualityTool(processRunner, gitQuery));
  offloadedRo(AnalyzeBugHotspotsTool(processRunner));
  offloadedRo(FindBugsByDeveloperTool(processRunner));
  registerReadOnly(GetRwGitDocumentationTool(registry));
  registerReadOnly(ReadReportSliceTool());
  mutating(InitRepositoryTool(git), outputSchema: _successOutputSchema);
  registerReadOnly(IsGitRepositoryTool(git, gitQuery), outputSchema: const {
    'type': 'object',
    'properties': {
      'isGitRepository': {'type': 'boolean'},
      'health_dashboard': {
        'type': 'object',
        'properties': {
          'current_branch': {'type': 'string'},
          'has_uncommitted_changes': {'type': 'boolean'},
          'last_commit_date': {'type': 'string'},
          'total_commits': {'type': 'integer'},
        },
      },
    },
  });
  mutating(CloneRepositoryTool(git), outputSchema: _successOutputSchema);
  mutating(CheckoutBranchTool(git), outputSchema: _successOutputSchema);
  mutating(FetchTagsTool(git), outputSchema: const {
    'type': 'object',
    'properties': {
      'tags': {'type': 'array'},
    },
  });
  offloadedRo(GetCommitsBetweenTool(git));
  offloadedRo(GetStatsTool(git, gitQuery), outputSchema: const {
    'type': 'object',
    'properties': {
      'numberOfChangedFiles': {'type': 'integer'},
      'insertions': {'type': 'integer'},
      'deletions': {'type': 'integer'},
      'stats_by_extension': {'type': 'object'},
    },
  });
  offloadedRo(GetContributionsByAuthorTool(git));
  mutating(CloneSpecificBranchTool(git), outputSchema: _successOutputSchema);
  offloadedRo(AnalyzeReleaseDeltaTool(gitQuery, processRunner));
  offloadedRo(AnalyzeBusFactorTool(processRunner, git));
  offloadedRo(AnalyzeLogicalCouplingTool(processRunner));
  offloadedRo(AnalyzeCodeVolatilityTool(processRunner));
  offloadedRo(AnalyzeRefactoringTool(processRunner));
  offloadedRo(EvaluateCommentsTool(processRunner));
  offloadedRo(DetectSecretsTool(processRunner));
  offloadedRo(AnalyzeCommitVelocityTool(processRunner));
  offloadedRo(AnalyzeDependencyDriftTool(processRunner));
  // Shares the single RA-SZZ core with the other SZZ-backed tools so
  // changelog bug linkage cannot drift from hotspot/developer attribution.
  offloadedRo(GenerateChangelogTool(gitQuery, SzzAlgorithm(processRunner)));
  offloadedRo(AuditComplianceTool(processRunner));
  offloadedRo(AnalyzeFileOwnershipTool(processRunner, gitQuery));
  offloadedRo(AnalyzeDartAstQualityTool(gitQuery));
  offloadedRo(AnalyzeArchitectureDriftTool(gitQuery));
  offloadedRo(AnalyzeCleanCodeTool());
  offloadedRo(CalculateUniversalLexicalMetricsTool(), outputSchema: const {
    'type': 'object',
    'properties': {
      'language_profile': {'type': 'string'},
      'cyclomatic_complexity': {'type': 'integer'},
      'npath_complexity': {'type': 'integer'},
      'abc_score': {'type': 'object'},
      'cognitive_complexity': {'type': 'integer'},
      'indentation_complexity': {'type': 'object'},
      'halstead_metrics': {'type': 'object'},
      'maintainability_index': {'type': 'object'},
    },
  });

  registry.registerPrompt(RwGitMcpReportingPrompt());

  return registry;
}
