/// ----------------------------------------------------------------------------
/// churn_classifier.dart
/// ----------------------------------------------------------------------------
library;

import 'package:rw_git/src/models/churn_metrics_dto.dart';

import '../finding.dart';
import '../path_key.dart';
import '../repo_stats.dart';
import '../severity.dart';

/// Flags files in the top decile of change frequency. Churn alone is only a
/// supporting signal (Elevated); it escalates to Critical exclusively when the
/// compound-finding correlator joins it with a complexity outlier on the same
/// file (actively-changing complex code).
class ChurnClassifier {
  const ChurnClassifier();

  List<Finding> classify(ChurnMetricsDto dto) {
    final churn = dto.fileChurn;
    if (churn.isEmpty) return const [];
    final threshold = RepoStats.topDecileThreshold(churn.values);
    if (threshold <= 0) return const [];

    final findings = <Finding>[];
    churn.forEach((file, count) {
      if (count < threshold) return;
      final normalized = PathKey.normalize(file);
      findings.add(Finding(
        category: 'churn',
        source: 'analyze_code_quality',
        severity: Severity.elevated,
        subject: normalized,
        metric: 'file_churn',
        value: count,
        band: 'top-decile change frequency',
        message: '$normalized changed $count times (top-decile churn).',
        evidence: {
          'file_churn': count,
          'top_decile_threshold': double.parse(threshold.toStringAsFixed(2)),
        },
      ));
    });
    return findings;
  }
}
