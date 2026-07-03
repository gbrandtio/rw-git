/// Deterministic interpretation layer: turns raw analysis DTOs into
/// severity-banded findings, correlates them into compound findings, and
/// assembles bounded report payloads a small model can narrate directly —
/// all without spending any LLM tokens on classification or ranking.
library;

export 'interpretation/compound_finding_correlator.dart';
export 'interpretation/finding.dart';
export 'interpretation/finding_classifier.dart';
export 'interpretation/path_key.dart';
export 'interpretation/report_hints.dart';
export 'interpretation/report_orchestrator.dart';
export 'interpretation/report_payload.dart';
export 'interpretation/report_tool_sources.dart';
export 'interpretation/repo_stats.dart';
export 'interpretation/severity.dart';
export 'interpretation/tool_hints.dart';
export 'interpretation/tool_hints_catalog.dart';
