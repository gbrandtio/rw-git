/// ----------------------------------------------------------------------------
/// dependency_classifier.dart
/// ----------------------------------------------------------------------------
library;

import '../models/analysis_type.dart';

import 'package:rw_git/src/models/dependency_freshness_dto.dart';

import '../models/finding.dart';
import '../models/severity.dart';

/// Classifies dependency freshness: how far each declared dependency lags the
/// latest published version. Major-behind carries breaking-change and
/// unpatched-CVE risk, so it is Critical.
class DependencyClassifier {
  const DependencyClassifier();

  List<Finding> classify(List<FreshnessResult> results) {
    final findings = <Finding>[];
    for (final r in results) {
      final Severity severity;
      final String band;
      switch (r.classification) {
        case 'major_behind':
          severity = Severity.critical;
          band = 'major version behind';
        case 'minor_behind':
          severity = Severity.moderate;
          band = 'minor version behind';
        case 'patch_behind':
          severity = Severity.low;
          band = 'patch version behind';
        default:
          continue;
      }

      findings.add(
        Finding(
          category: 'dependency',
          source: [AnalysisType.dependencyDrift],
          severity: severity,
          subject: r.name,
          metric: 'freshness',
          value: r.classification,
          band: band,
          evidence: {
            'declared_version': r.declaredVersion,
            if (r.latestVersion != null) 'latest_version': r.latestVersion,
          },
        ),
      );
    }
    return findings;
  }
}
