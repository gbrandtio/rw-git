/// ----------------------------------------------------------------------------
/// mcp_analysis_mapping.dart
/// ----------------------------------------------------------------------------
/// Provides the bridging mappings between domain AnalysisType enums and their
/// specific MCP tool string identifiers.
library;

import '../../intelligence/interpretation/models/analysis_type.dart';

const Map<AnalysisType, String> mcpToolNameForAnalysis = {
  AnalysisType.busFactor: 'analyze_bus_factor',
  AnalysisType.logicalCoupling: 'analyze_logical_coupling',
  AnalysisType.architectureDrift: 'analyze_architecture_drift',
  AnalysisType.dependencyDrift: 'analyze_dependency_drift',
  AnalysisType.fileOwnership: 'analyze_file_ownership',
  AnalysisType.refactoring: 'analyze_refactoring',
  AnalysisType.bugHotspots: 'analyze_bug_hotspots',
  AnalysisType.codeVolatility: 'analyze_code_volatility',
  AnalysisType.commitVelocity: 'analyze_commit_velocity',
  AnalysisType.releaseDelta: 'analyze_release_delta',
  AnalysisType.changelog: 'generate_changelog',
  AnalysisType.cleanCode: 'analyze_clean_code',
  AnalysisType.codeQuality: 'analyze_code_quality',
  AnalysisType.dartAstQuality: 'analyze_dart_ast_quality',
  AnalysisType.universalLexicalMetrics: 'calculate_universal_lexical_metrics',
  AnalysisType.evaluateComments: 'evaluate_comments',
  AnalysisType.auditCompliance: 'audit_compliance',
  AnalysisType.detectSecrets: 'detect_secrets_in_commits',
  AnalysisType.contributionsByAuthor: 'get_contributions_by_author',
  AnalysisType.stats: 'get_stats',
  AnalysisType.commitsBetween: 'get_commits_between',
};

final Map<String, AnalysisType> analysisTypeForMcpTool = {
  for (final entry in mcpToolNameForAnalysis.entries) entry.value: entry.key,
};
