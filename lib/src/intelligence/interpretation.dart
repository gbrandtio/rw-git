/// Deterministic interpretation layer: turns raw analysis DTOs into
/// severity-banded findings, correlates them into compound findings, and
/// assembles bounded report payloads a small model can narrate directly —
/// all without spending any LLM tokens on classification or ranking.
library;

export 'interpretation/orchestration/compound_finding_correlator.dart';
export 'interpretation/models/finding.dart';
export 'interpretation/orchestration/finding_classifier.dart';
export 'interpretation/utils/path_key.dart';
export 'interpretation/orchestration/refactoring_target_ranker.dart';
export 'interpretation/models/report_hints.dart';
export 'interpretation/models/report_payload.dart';
export 'interpretation/models/report_analysis_sources.dart';
export 'interpretation/utils/repo_stats.dart';
export 'interpretation/models/severity.dart';
export 'interpretation/models/tool_hints.dart';
export 'interpretation/catalogs/analysis_hints_catalog.dart';
export 'interpretation/models/analysis_type.dart';
