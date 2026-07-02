/// ----------------------------------------------------------------------------
/// dependency_classifier.dart
/// ----------------------------------------------------------------------------
library;

import 'package:rw_git/src/models/dependency_freshness_dto.dart';

import '../finding.dart';
import '../severity.dart';

/// Classifies dependency freshness: how far each declared dependency lags the
/// latest published version. Major-behind carries breaking-change and
/// unpatched-CVE risk, so it is Critical.
class DependencyClassifier {
  const DependencyClassifier();

  /// Compact citation tag carried inline on every finding.
  static const String researchBasis =
      'Dependency freshness lag (Raemaekers et al. 2012; Decan et al. 2018)';

  /// Fuller research rationale carried only in the offloaded full report.
  static const String researchRationale =
      'Dependency freshness measures how far a declared version lags the '
      'latest release (Raemaekers et al., MSR 2012); lag correlates with '
      'unpatched vulnerabilities and compounding upgrade cost across '
      'packaging ecosystems (Decan et al., MSR 2018).';

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

      findings.add(Finding(
        category: 'dependency',
        source: 'analyze_dependency_drift',
        severity: severity,
        subject: r.name,
        metric: 'freshness',
        value: r.classification,
        band: band,
        basis: researchBasis,
        rationale: researchRationale,
        message: '${r.name} is $band (declared ${r.declaredVersion}'
            '${r.latestVersion != null ? ', latest ${r.latestVersion}' : ''}).',
        evidence: {
          'declared_version': r.declaredVersion,
          if (r.latestVersion != null) 'latest_version': r.latestVersion,
        },
      ));
    }
    return findings;
  }
}
