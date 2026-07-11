import 'dart:io';

import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

/// [reportAnalysisSources] is the single source of truth both [ReportPayload]'s
/// hint aggregation and the generated skill `<deep_dive>` tool lists rely on
/// (see `test/mcp/prompts_sync_test.dart` for the latter). This guards it
/// against drifting from what `ReportOrchestrator` actually invokes.
///
/// The cross-check against `ReportOrchestrator` is deliberately static
/// (source-text inspection) rather than a live run against a real
/// repository: a live run can only ever prove a tool's classifier *fired*
/// for the specific commit history under test, not that it never will, so
/// a report whose one contributing commit happens to produce zero material
/// findings for some source would make a live-equality test flaky. Every
/// classifier this project defines is invoked through exactly one, uniquely
/// named class per catalog tool, so checking that class's name appears in
/// the relevant report method's source text is both deterministic and a
/// faithful proxy for "this tool's classifier runs in this report."
void main() {
  test(
    'every tool name in reportAnalysisSources is a analysisHintsCatalog key',
    () {
      for (final entry in reportAnalysisSources.entries) {
        for (final type in entry.value) {
          expect(
            analysisHintsCatalog.containsKey(type),
            isTrue,
            reason:
                'reportAnalysisSources[\'${entry.key}\'] references unknown '
                'catalog type $type',
          );
        }
      }
    },
  );

  test('reportAnalysisSources has exactly the five known report types', () {
    expect(reportAnalysisSources.keys.toSet(), {
      'technical',
      'security',
      'pm',
      'code_review',
      'repository_audit',
    });
  });

  test(
    'reportAnalysisSources exactly matches the classifiers ReportOrchestrator '
    'invokes per report',
    () {
      final source =
          File(
            'lib/src/mcp/reports/report_orchestrator.dart',
          ).readAsStringSync();

      String methodBody(String signature) {
        final start = source.indexOf(signature);
        expect(
          start,
          greaterThanOrEqualTo(0),
          reason: 'report_orchestrator.dart no longer declares $signature',
        );
        final end = source.indexOf('Future<', start + signature.length);
        return source.substring(start, end == -1 ? source.length : end);
      }

      String combinedBody(List<String> signatures) =>
          signatures.map(methodBody).join('\n');

      final reportMethodSignatures = <String, List<String>>{
        'technical': [
          'Future<ReportPayload> technicalReport(',
          'Future<TechnicalAnalysis> _technicalFindings(',
          'Future<List<List<String>>> _detectImportCycles(',
        ],
        'security': [
          'Future<ReportPayload> securityReport(',
          'Future<List<Finding>> _securityFindings(',
        ],
        'pm': ['Future<ReportPayload> pmReport('],
        'code_review': ['Future<ReportPayload> codeReviewReport('],
        'repository_audit': [
          'Future<ReportPayload> repositoryAudit(',
          'Future<TechnicalAnalysis> _technicalFindings(',
          'Future<List<List<String>>> _detectImportCycles(',
          'Future<List<Finding>> _securityFindings(',
        ],
      };

      for (final reportType in reportAnalysisSources.keys) {
        final body = combinedBody(reportMethodSignatures[reportType]!);
        final declared = reportAnalysisSources[reportType]!.toSet();

        for (final entry in _toolMarkers.entries) {
          final invoked = body.contains(entry.value);
          final isDeclared = declared.contains(entry.key);
          expect(
            invoked,
            isDeclared,
            reason:
                invoked
                    ? 'reportAnalysisSources[\'$reportType\'] is missing '
                        '${entry.key} (its classifier, ${entry.value}, is '
                        'invoked by this report)'
                    : 'reportAnalysisSources[\'$reportType\'] declares '
                        '${entry.key}, but its classifier, ${entry.value}, is '
                        'never invoked by this report',
          );
        }
      }
    },
  );
}

/// Maps each catalog tool this project's reports can produce findings for to
/// the uniquely named class whose presence in `report_orchestrator.dart`'s
/// source proves that tool's classifier is invoked.
const Map<AnalysisType, String> _toolMarkers = {
  AnalysisType.codeQuality: 'AdvancedMetricsHeuristic',
  AnalysisType.fileOwnership: 'calculateChurnWithAuthors',
  AnalysisType.bugHotspots: 'BugHotspotsHeuristic',
  AnalysisType.logicalCoupling: 'LogicalCouplingAlgorithm',
  AnalysisType.codeVolatility: 'CodeVolatilityAlgorithm',
  AnalysisType.universalLexicalMetrics: 'BoundedLexicalMetricsSampler',
  AnalysisType.refactoring: 'RefactoringDetectionAlgorithm',
  AnalysisType.detectSecrets: 'SecretsScanner',
  AnalysisType.auditCompliance: 'ComplianceScanner',
  AnalysisType.dependencyDrift: 'DependencyFreshnessChecker',
  AnalysisType.busFactor: 'BusFactorAlgorithm',
  AnalysisType.commitVelocity: 'CommitVelocityHeuristic',
  AnalysisType.architectureDrift: 'ArchitectureDriftAlgorithm',
  AnalysisType.cleanCode: 'CleanCodeAnalyzer',
  AnalysisType.dartAstQuality: 'DartAstAnalyzer',
};
