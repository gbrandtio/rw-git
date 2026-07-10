/// ----------------------------------------------------------------------------
/// report_analysis_sources.dart
/// ----------------------------------------------------------------------------
/// Canonical, hand-maintained mapping from each report type (as returned in
/// `ReportPayload.reportType`) to the ordered list of [AnalysisType]s whose
/// classifiers feed that report's findings in `ReportOrchestrator`. This is
/// the single source of truth consulted by `tool/prompt_codegen.dart` to
/// generate the reporting skill's per-report `<deep_dive>` raw-tool lists,
/// so those lists can never drift from what each report actually runs — see
/// `test/intelligence/interpretation/report_analysis_sources_test.dart`
/// for the drift guard against `ReportOrchestrator`'s real classifier calls.
///
/// Order matters: it drives the order tools are listed in generated
/// deep-dive prose, roughly most-central signal first.
library;

import 'analysis_type.dart';

const Map<String, List<AnalysisType>> reportAnalysisSources = {
  'technical': [
    AnalysisType.codeQuality,
    AnalysisType.fileOwnership,
    AnalysisType.bugHotspots,
    AnalysisType.logicalCoupling,
    AnalysisType.codeVolatility,
    AnalysisType.universalLexicalMetrics,
    AnalysisType.refactoring,
    AnalysisType.architectureDrift,
    AnalysisType.cleanCode,
    AnalysisType.dartAstQuality,
  ],
  'security': [
    AnalysisType.detectSecrets,
    AnalysisType.auditCompliance,
    AnalysisType.dependencyDrift,
  ],
  'pm': [
    AnalysisType.busFactor,
    AnalysisType.fileOwnership,
    AnalysisType.bugHotspots,
    AnalysisType.commitVelocity,
  ],
  'code_review': [
    AnalysisType.codeQuality,
    AnalysisType.detectSecrets,
    AnalysisType.bugHotspots,
    AnalysisType.fileOwnership,
    AnalysisType.universalLexicalMetrics,
    AnalysisType.cleanCode,
    AnalysisType.refactoring,
  ],
  'repository_audit': [
    AnalysisType.busFactor,
    AnalysisType.codeQuality,
    AnalysisType.bugHotspots,
    AnalysisType.logicalCoupling,
    AnalysisType.codeVolatility,
    AnalysisType.universalLexicalMetrics,
    AnalysisType.refactoring,
    AnalysisType.architectureDrift,
    AnalysisType.cleanCode,
    AnalysisType.dartAstQuality,
    AnalysisType.fileOwnership,
    AnalysisType.commitVelocity,
    AnalysisType.detectSecrets,
    AnalysisType.auditCompliance,
    AnalysisType.dependencyDrift,
  ],
};
