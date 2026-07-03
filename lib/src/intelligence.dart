/// Public, MCP-independent entry points for git-history analysis and
/// architecture/security/static-analysis algorithms. Each class depends only
/// on [ProcessRunner] and returns a strongly-typed DTO, so consumers can use
/// them directly without running the MCP server.
library;

export 'intelligence/architecture/bus_factor_algorithm.dart';
export 'intelligence/architecture/logical_coupling_algorithm.dart';
export 'intelligence/architecture/refactoring_detection_algorithm.dart';
export 'intelligence/history/algorithms/code_volatility_algorithm.dart';
export 'intelligence/history/algorithms/szz_algorithm.dart';
export 'intelligence/history/heuristics/advanced_metrics_heuristic.dart';
export 'intelligence/history/heuristics/bug_hotspots_heuristic.dart';
export 'intelligence/history/heuristics/churn_heuristic.dart';
export 'intelligence/history/heuristics/commit_velocity_heuristic.dart';
export 'intelligence/history/heuristics/mega_commits_heuristic.dart';
export 'intelligence/history/heuristics/suspicious_commits_heuristic.dart';
export 'intelligence/interpretation.dart';
export 'intelligence/security/compliance_scanner.dart';
export 'intelligence/security/dependency_manifest_parser.dart';
export 'intelligence/security/dependency_freshness_checker.dart';
export 'intelligence/security/registry_adapters.dart';
export 'intelligence/security/semver_compare.dart';
export 'intelligence/security/secrets_scanner.dart';
export 'intelligence/static_analysis/dart/dart_ast_analyzer.dart';
export 'intelligence/static_analysis/metrics/bounded_lexical_metrics_sampler.dart';
