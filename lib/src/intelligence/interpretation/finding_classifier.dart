/// ----------------------------------------------------------------------------
/// finding_classifier.dart
/// ----------------------------------------------------------------------------
/// Thin aggregator over the individual classifiers so the report orchestrator
/// can turn each algorithm DTO into findings through one typed façade instead
/// of wiring up ten classes by hand.
library;

import 'package:rw_git/src/models/advanced_code_quality_dto.dart';
import 'package:rw_git/src/models/bug_hotspot_dto.dart';
import 'package:rw_git/src/models/bus_factor_dto.dart';
import 'package:rw_git/src/models/churn_metrics_dto.dart';
import 'package:rw_git/src/models/churn_metrics_with_authors_dto.dart';
import 'package:rw_git/src/models/code_volatility_dto.dart';
import 'package:rw_git/src/models/compliance_report_dto.dart';
import 'package:rw_git/src/models/dependency_freshness_dto.dart';
import 'package:rw_git/src/models/logical_coupling_dto.dart';

import 'classifiers/bug_hotspot_classifier.dart';
import 'classifiers/bus_factor_classifier.dart';
import 'classifiers/churn_classifier.dart';
import 'classifiers/compliance_classifier.dart';
import 'classifiers/complexity_classifier.dart';
import 'classifiers/dependency_classifier.dart';
import 'classifiers/logical_coupling_classifier.dart';
import 'classifiers/ownership_classifier.dart';
import 'classifiers/secrets_classifier.dart';
import 'classifiers/volatility_classifier.dart';
import 'finding.dart';

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
}
