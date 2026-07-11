/// ----------------------------------------------------------------------------
/// logical_coupling_classifier.dart
/// ----------------------------------------------------------------------------
library;

import '../models/analysis_type.dart';

import 'package:rw_git/src/models/logical_coupling_dto.dart';

import '../models/finding.dart';
import '../utils/path_key.dart';
import '../models/severity.dart';

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

      final normalizedPathA = PathKey.normalize(pair.fileA);
      final normalizedPathB = PathKey.normalize(pair.fileB);
      final crossModule =
          PathKey.topDir(normalizedPathA) != PathKey.topDir(normalizedPathB);
      final pct = (confidence * 100).toStringAsFixed(1);
      findings.add(
        Finding(
          category: 'coupling',
          source: [AnalysisType.logicalCoupling],
          severity: severity,
          subject: normalizedPathA,
          metric: 'co_change_confidence',
          value: double.parse((confidence * 100).toStringAsFixed(2)),
          band: band,
          evidence: {
            'file_a': normalizedPathA,
            'file_b': normalizedPathB,
            'co_change_count': pair.coChangeCount,
            'confidence_percentage': pct,
            'cross_module': crossModule,
          },
        ),
      );
    }
    return findings;
  }
}
