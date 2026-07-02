/// ----------------------------------------------------------------------------
/// ownership_classifier.dart
/// ----------------------------------------------------------------------------
library;

import 'package:rw_git/src/models/churn_metrics_with_authors_dto.dart';

import '../finding.dart';
import '../path_key.dart';
import '../severity.dart';

/// Classifies per-file ownership concentration. A single author owning the
/// majority of a file's changes is a single point of failure — the per-file
/// analogue of a low bus factor.
class OwnershipClassifier {
  const OwnershipClassifier();

  /// Files whose top author holds less than this share are treated as healthy.
  static const double _minShare = 0.30;

  /// Compact citation tag carried inline on every finding.
  static const String researchBasis =
      'Ownership concentration and defects (Bird et al. 2011)';

  /// Fuller research rationale carried only in the offloaded full report.
  static const String researchRationale =
      'Components dominated by a single author accumulate knowledge no '
      'reviewer shares, and ownership structure measurably affects defect '
      'rates (Bird et al., FSE 2011) — the per-file analogue of a low bus '
      'factor.';

  List<Finding> classify(ChurnMetricsWithAuthorsDto dto) {
    final findings = <Finding>[];
    dto.fileChurn.forEach((file, stats) {
      if (stats.total <= 0 || stats.authors.isEmpty) return;
      final top =
          stats.authors.entries.reduce((a, b) => a.value >= b.value ? a : b);
      final share = top.value / stats.total;
      if (share < _minShare) return;

      final Severity severity;
      final String band;
      if (share > 0.50) {
        severity = Severity.critical;
        band = '> 50% single-author ownership';
      } else {
        severity = Severity.moderate;
        band = '30-50% single-author ownership';
      }

      final normalized = PathKey.normalize(file);
      final pct = (share * 100).toStringAsFixed(1);
      findings.add(Finding(
        category: 'ownership',
        source: 'analyze_file_ownership',
        severity: severity,
        subject: normalized,
        metric: 'single_author_ownership',
        value: double.parse((share * 100).toStringAsFixed(2)),
        band: band,
        basis: researchBasis,
        rationale: researchRationale,
        message: '${top.key} owns $pct% of changes to $normalized.',
        evidence: {
          'top_author': top.key,
          'author_changes': top.value,
          'total_changes': stats.total,
        },
      ));
    });
    return findings;
  }
}
