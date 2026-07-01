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

      final a = PathKey.normalize(pair.fileA);
      final b = PathKey.normalize(pair.fileB);
      final crossModule = PathKey.topDir(a) != PathKey.topDir(b);
      final pct = (confidence * 100).toStringAsFixed(1);
      findings.add(Finding(
        category: 'coupling',
        source: 'analyze_logical_coupling',
        severity: severity,
        subject: a,
        metric: 'co_change_confidence',
        value: double.parse((confidence * 100).toStringAsFixed(2)),
        band: band,
        message: '$a and $b change together $pct% of the time'
            '${crossModule ? ' across module boundaries' : ''} '
            '(${pair.coChangeCount} co-changes).',
        evidence: {
          'file_a': a,
          'file_b': b,
          'co_change_count': pair.coChangeCount,
          'confidence_percentage': pct,
          'cross_module': crossModule,
        },
      ));
    }
    return findings;
  }
}
