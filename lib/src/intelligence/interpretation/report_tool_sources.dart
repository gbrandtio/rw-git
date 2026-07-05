/// ----------------------------------------------------------------------------
/// report_tool_sources.dart
/// ----------------------------------------------------------------------------
/// Canonical, hand-maintained mapping from each report type (as returned in
/// `ReportPayload.reportType`) to the ordered list of [toolHintsCatalog] keys
/// / MCP tool names whose classifiers feed that report's findings in
/// `ReportOrchestrator`. This is the single source of truth consulted by
/// `tool/prompt_codegen.dart` to generate the reporting skill's per-report
/// `<deep_dive>` raw-tool lists, so those lists can never drift from what
/// each report actually runs — see
/// `test/intelligence/interpretation/report_tool_sources_test.dart`
/// for the drift guard against `ReportOrchestrator`'s real classifier calls.
///
/// Order matters: it drives the order tools are listed in generated
/// deep-dive prose, roughly most-central signal first.
library;

const Map<String, List<String>> reportToolSources = {
  'technical': [
    'analyze_code_quality',
    'analyze_file_ownership',
    'analyze_bug_hotspots',
    'analyze_logical_coupling',
    'analyze_code_volatility',
    'calculate_universal_lexical_metrics',
    'analyze_refactoring',
    'analyze_architecture_drift',
    'analyze_clean_code',
    'analyze_dart_ast_quality',
  ],
  'security': [
    'detect_secrets_in_commits',
    'audit_compliance',
    'analyze_dependency_drift',
  ],
  'pm': [
    'analyze_bus_factor',
    'analyze_file_ownership',
    'analyze_bug_hotspots',
    'analyze_commit_velocity',
  ],
  'code_review': [
    'analyze_code_quality',
    'detect_secrets_in_commits',
    'analyze_bug_hotspots',
    'analyze_file_ownership',
    'calculate_universal_lexical_metrics',
    'analyze_clean_code',
    'analyze_refactoring',
  ],
  'repository_audit': [
    'analyze_bus_factor',
    'analyze_code_quality',
    'analyze_bug_hotspots',
    'analyze_logical_coupling',
    'analyze_code_volatility',
    'calculate_universal_lexical_metrics',
    'analyze_refactoring',
    'analyze_architecture_drift',
    'analyze_clean_code',
    'analyze_dart_ast_quality',
    'analyze_file_ownership',
    'analyze_commit_velocity',
    'detect_secrets_in_commits',
    'audit_compliance',
    'analyze_dependency_drift',
  ],
};
