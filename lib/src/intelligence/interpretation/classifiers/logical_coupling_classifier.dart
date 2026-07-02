/// ----------------------------------------------------------------------------
/// logical_coupling_classifier.dart
/// ----------------------------------------------------------------------------
library;

import 'package:rw_git/src/models/logical_coupling_dto.dart';

import '../finding.dart';
import '../path_key.dart';
import '../severity.dart';

/// Classifies co-change coupling strength between file pairs and records
/// whether the pair spans two declared modules (top-level directories), which
/// the correlator uses to escalate strong cross-module coupling to an
/// architecture smell.
class LogicalCouplingClassifier {
  const LogicalCouplingClassifier();

  /// Compact citation tag carried inline on every finding.
  static const String researchBasis =
      'Co-change logical coupling (Gall et al. 1998; Zimmermann et al. 2004)';

  /// Fuller research rationale carried only in the offloaded full report.
  static const String researchRationale =
      'Files that repeatedly change together are logically coupled even '
      'without a static dependency (Gall et al., ICSM 1998); co-change '
      'history predicts where a change must propagate next (Zimmermann et '
      'al., ICSE 2004).';

  List<Finding> classify(List<LogicalCouplingDto> pairs) {
    final findings = <Finding>[];
    for (final pair in pairs) {
      final confidence = pair.confidence; // 0..1
      final Severity severity;
      final String band;
      if (confidence > 0.60) {
        severity = Severity.high;
        band = '> 60% co-change confidence (strong)';
      } else if (confidence >= 0.30) {
        severity = Severity.moderate;
        band = '30-60% co-change confidence (moderate)';
      } else {
        continue;
      }

      final normalizedPathA = PathKey.normalize(pair.fileA);
      final normalizedPathB = PathKey.normalize(pair.fileB);
      final crossModule =
          PathKey.topDir(normalizedPathA) != PathKey.topDir(normalizedPathB);
      final pct = (confidence * 100).toStringAsFixed(1);
      findings.add(Finding(
        category: 'coupling',
        source: 'analyze_logical_coupling',
        severity: severity,
        subject: normalizedPathA,
        metric: 'co_change_confidence',
        value: double.parse((confidence * 100).toStringAsFixed(2)),
        band: band,
        basis: researchBasis,
        rationale: researchRationale,
        message: '$normalizedPathA and $normalizedPathB change together '
            '$pct% of the time'
            '${crossModule ? ' across module boundaries' : ''} '
            '(${pair.coChangeCount} co-changes).',
        evidence: {
          'file_a': normalizedPathA,
          'file_b': normalizedPathB,
          'co_change_count': pair.coChangeCount,
          'confidence_percentage': pct,
          'cross_module': crossModule,
        },
      ));
    }
    return findings;
  }
}
