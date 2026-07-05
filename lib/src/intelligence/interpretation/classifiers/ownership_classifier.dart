/// ----------------------------------------------------------------------------
/// ownership_classifier.dart
/// ----------------------------------------------------------------------------
library;

import 'package:rw_git/src/constants.dart';
import 'package:rw_git/src/models/churn_metrics_with_authors_dto.dart';

import '../finding.dart';
import '../path_key.dart';
import '../severity.dart';

/// Classifies per-file ownership structure along both axes Bird et al.
/// (FSE 2011) found predictive of defects: a single author owning the
/// majority of a file's changes (single point of failure — the per-file
/// analogue of a low bus factor), and, independently, a file touched by
/// many *minor* contributors (authors below
/// [birdMinorContributorShareThreshold] of its changes), which Bird's
/// second finding shows is even more defect-prone than concentration.
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

  /// Compact citation tag for the minor-contributor findings.
  static const String minorContributorBasis =
      'Minor-contributor defect signal (Bird et al. 2011)';

  /// Fuller rationale for the minor-contributor findings.
  static const String minorContributorRationale =
      'Bird et al. (FSE 2011) found the number of minor contributors — '
      'authors each holding under 5% of a component\'s changes — to be a '
      'stronger defect predictor than ownership concentration itself: many '
      'shallow edits by people without deep context accumulate defects.';

  List<Finding> classify(ChurnMetricsWithAuthorsDto dto) {
    final findings = <Finding>[];
    dto.fileChurn.forEach((file, stats) {
      if (stats.total <= 0 || stats.authors.isEmpty) return;
      final normalized = PathKey.normalize(file);

      final top =
          stats.authors.entries.reduce((a, b) => a.value >= b.value ? a : b);
      final share = top.value / stats.total;
      if (share >= _minShare) {
        final Severity severity;
        final String band;
        if (share > 0.50) {
          severity = Severity.critical;
          band = '> 50% single-author ownership';
        } else {
          severity = Severity.moderate;
          band = '30-50% single-author ownership';
        }

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
      }

      // Bird's second finding: many minor contributors predict defects
      // independently of who the majority owner is.
      final minorContributors = stats.authors.entries
          .where((author) =>
              author.value / stats.total < birdMinorContributorShareThreshold)
          .map((author) => author.key)
          .toList();
      if (minorContributors.length >= birdMinorContributorMinimumCount) {
        findings.add(Finding(
          category: 'ownership',
          source: 'analyze_file_ownership',
          severity: Severity.elevated,
          subject: normalized,
          metric: 'minor_contributor_count',
          value: minorContributors.length,
          band: '>= $birdMinorContributorMinimumCount contributors below '
              '${(birdMinorContributorShareThreshold * 100).round()}% share',
          basis: minorContributorBasis,
          rationale: minorContributorRationale,
          message: '$normalized has ${minorContributors.length} minor '
              'contributors, each under '
              '${(birdMinorContributorShareThreshold * 100).round()}% of its '
              'changes — a defect-proneness signal independent of the '
              'majority owner.',
          evidence: {
            'minor_contributor_count': minorContributors.length,
            'minor_contributors_sample': minorContributors
                .take(aggregateFindingEvidenceSampleSize)
                .toList(),
            'total_authors': stats.authors.length,
          },
        ));
      }
    });
    return findings;
  }
}
