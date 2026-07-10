/// ----------------------------------------------------------------------------
/// finding_classifier.dart
/// ----------------------------------------------------------------------------
/// Thin aggregator over the individual classifiers so the report orchestrator
/// can turn each algorithm DTO into findings through one typed façade instead
/// of wiring up ten classes by hand.
library;

import 'package:rw_git/src/models/advanced_code_quality_dto.dart';
import 'package:rw_git/src/models/architecture_drift_dto.dart';
import 'package:rw_git/src/models/bug_hotspot_dto.dart';
import 'package:rw_git/src/models/bus_factor_dto.dart';
import 'package:rw_git/src/models/churn_metrics_dto.dart';
import 'package:rw_git/src/models/churn_metrics_with_authors_dto.dart';
import 'package:rw_git/src/models/clean_code_metrics_dto.dart';
import 'package:rw_git/src/models/code_volatility_dto.dart';
import 'package:rw_git/src/models/commit_velocity_dto.dart';
import 'package:rw_git/src/models/compliance_report_dto.dart';
import 'package:rw_git/src/models/dependency_freshness_dto.dart';
import 'package:rw_git/src/models/file_lexical_metrics_dto.dart';
import 'package:rw_git/src/models/logical_coupling_dto.dart';
import 'package:rw_git/src/models/refactoring_dto.dart';

import '../classifiers/architecture_drift_classifier.dart';
import '../classifiers/bug_hotspot_classifier.dart';
import '../classifiers/bus_factor_classifier.dart';
import '../classifiers/churn_classifier.dart';
import '../classifiers/clean_code_classifier.dart';
import '../classifiers/commit_hygiene_classifier.dart';
import '../classifiers/dart_ast_classifier.dart';
import '../classifiers/commit_velocity_classifier.dart';
import '../classifiers/compliance_classifier.dart';
import '../classifiers/complexity_classifier.dart';
import '../classifiers/dependency_classifier.dart';
import '../classifiers/lexical_complexity_classifier.dart';
import '../classifiers/logical_coupling_classifier.dart';
import '../classifiers/ownership_classifier.dart';
import '../classifiers/refactoring_context_classifier.dart';
import '../classifiers/secrets_classifier.dart';
import '../classifiers/volatility_classifier.dart';
import '../models/finding.dart';

/// Applies every deterministic classifier behind typed methods.
class FindingClassifier {
  const FindingClassifier();

  List<Finding> fromBusFactor(BusFactorDto dto) =>
      const BusFactorClassifier().classify(dto);

  List<Finding> fromOwnership(ChurnMetricsWithAuthorsDto dto) =>
      const OwnershipClassifier().classify(dto);

  List<Finding> fromBugHotspots(BugHotspotDto dto) =>
      const BugHotspotClassifier().classify(dto);

  List<Finding> fromComplexity(AdvancedCodeQualityDto dto) =>
      const ComplexityClassifier().classify(dto);

  List<Finding> fromChurn(ChurnMetricsDto dto) =>
      const ChurnClassifier().classify(dto);

  List<Finding> fromLogicalCoupling(List<LogicalCouplingDto> pairs) =>
      const LogicalCouplingClassifier().classify(pairs);

  List<Finding> fromVolatility(List<CodeVolatilityDto> files) =>
      const VolatilityClassifier().classify(files);

  List<Finding> fromDependencyFreshness(List<FreshnessResult> results) =>
      const DependencyClassifier().classify(results);

  List<Finding> fromCompliance(ComplianceReportDto dto) =>
      const ComplianceClassifier().classify(dto);

  List<Finding> fromSecrets(List<String> rawFindings) =>
      const SecretsClassifier().classify(rawFindings);

  List<Finding> fromLexicalMetrics(List<FileLexicalMetricsDto> files) =>
      const LexicalComplexityClassifier().classify(files);

  List<Finding> fromImportCycles(List<List<String>> cycles) =>
      const DartAstClassifier().classifyImportCycles(cycles);

  List<Finding> fromCleanCode(List<CleanCodeMetricsDto> files) =>
      const CleanCodeClassifier().classify(files);

  List<Finding> fromArchitectureDrift(ArchitectureDriftDto dto) =>
      const ArchitectureDriftClassifier().classify(dto);

  List<Finding> fromCommitVelocity(CommitVelocityDto dto) =>
      const CommitVelocityClassifier().classify(dto);

  List<Finding> fromMegaCommits(List<String> megaCommits) =>
      const CommitHygieneClassifier().classifyMegaCommits(megaCommits);

  List<Finding> fromSuspiciousCommits(List<String> suspiciousCommits) =>
      const CommitHygieneClassifier()
          .classifySuspiciousCommits(suspiciousCommits);

  List<Finding> fromRefactoringActivity(List<RefactoringDto> refactorings) =>
      const RefactoringContextClassifier().classify(refactorings);

  /// Downgrades churn-derived findings whose subject was refactored; see
  /// [RefactoringContextClassifier.annotate].
  List<Finding> applyRefactoringContext(
          List<Finding> findings, List<RefactoringDto> refactorings) =>
      const RefactoringContextClassifier().annotate(findings, refactorings);
}
