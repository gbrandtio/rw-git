import 'dart:io';

import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

/// [reportToolSources] is the single source of truth both [ReportPayload]'s
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
  test('every tool name in reportToolSources is a toolHintsCatalog key', () {
    for (final entry in reportToolSources.entries) {
      for (final tool in entry.value) {
        expect(toolHintsCatalog.containsKey(tool), isTrue,
            reason: 'reportToolSources[\'${entry.key}\'] references unknown '
                'catalog tool $tool');
      }
    }
  });

  test('reportToolSources has exactly the five known report types', () {
    expect(
      reportToolSources.keys.toSet(),
      {'technical', 'security', 'pm', 'code_review', 'repository_audit'},
    );
  });

  test(
      'reportToolSources exactly matches the classifiers ReportOrchestrator '
      'invokes per report', () {
    final source = File('lib/src/intelligence/interpretation/'
            'report_orchestrator.dart')
        .readAsStringSync();

    String methodBody(String signature) {
      final start = source.indexOf(signature);
      expect(start, greaterThanOrEqualTo(0),
          reason: 'report_orchestrator.dart no longer declares $signature');
      final end = source.indexOf('Future<', start + signature.length);
      return source.substring(start, end == -1 ? source.length : end);
    }

    String combinedBody(List<String> signatures) =>
        signatures.map(methodBody).join('\n');

    final reportMethodSignatures = <String, List<String>>{
      'technical': [
        'Future<ReportPayload> technicalReport(',
        'Future<List<Finding>> _technicalFindings(',
      ],
      'security': [
        'Future<ReportPayload> securityReport(',
        'Future<List<Finding>> _securityFindings(',
      ],
      'pm': ['Future<ReportPayload> pmReport('],
      'code_review': ['Future<ReportPayload> codeReviewReport('],
      'repository_audit': [
        'Future<ReportPayload> repositoryAudit(',
        'Future<List<Finding>> _technicalFindings(',
        'Future<List<Finding>> _securityFindings(',
      ],
    };

    for (final reportType in reportToolSources.keys) {
      final body = combinedBody(reportMethodSignatures[reportType]!);
      final declared = reportToolSources[reportType]!.toSet();

      for (final entry in _toolMarkers.entries) {
        final invoked = body.contains(entry.value);
        final isDeclared = declared.contains(entry.key);
        expect(invoked, isDeclared,
            reason: invoked
                ? 'reportToolSources[\'$reportType\'] is missing '
                    '${entry.key} (its classifier, ${entry.value}, is '
                    'invoked by this report)'
                : 'reportToolSources[\'$reportType\'] declares '
                    '${entry.key}, but its classifier, ${entry.value}, is '
                    'never invoked by this report');
      }
    }
  });
}

/// Maps each catalog tool this project's reports can produce findings for to
/// the uniquely named class whose presence in `report_orchestrator.dart`'s
/// source proves that tool's classifier is invoked.
const Map<String, String> _toolMarkers = {
  'analyze_code_quality': 'AdvancedMetricsHeuristic',
  'analyze_file_ownership': 'calculateChurnWithAuthors',
  'analyze_bug_hotspots': 'BugHotspotsHeuristic',
  'analyze_logical_coupling': 'LogicalCouplingAlgorithm',
  'analyze_code_volatility': 'CodeVolatilityAlgorithm',
  'calculate_universal_lexical_metrics': 'BoundedLexicalMetricsSampler',
  'analyze_refactoring': 'RefactoringDetectionAlgorithm',
  'detect_secrets_in_commits': 'SecretsScanner',
  'audit_compliance': 'ComplianceScanner',
  'analyze_dependency_drift': 'DependencyFreshnessChecker',
  'analyze_bus_factor': 'BusFactorAlgorithm',
  'analyze_commit_velocity': 'CommitVelocityHeuristic',
};
