/// ----------------------------------------------------------------------------
/// churn_classifier.dart
/// ----------------------------------------------------------------------------
library;

import '../models/analysis_type.dart';

import 'package:rw_git/src/models/churn_metrics_dto.dart';

import '../models/finding.dart';
import '../utils/path_key.dart';
import '../utils/repo_stats.dart';
import '../models/severity.dart';

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
        source: [AnalysisType.codeQuality],
        severity: Severity.elevated,
        subject: normalized,
        metric: 'file_churn',
        value: count,
        band: 'top-decile change frequency',
        evidence: {
          'file_churn': count,
          'top_decile_threshold': double.parse(threshold.toStringAsFixed(2)),
        },
      ));
    });
    return findings;
  }
}
