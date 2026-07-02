/// ----------------------------------------------------------------------------
/// commit_velocity_classifier.dart
/// ----------------------------------------------------------------------------
library;

import 'package:rw_git/src/constants.dart';
import 'package:rw_git/src/models/commit_velocity_dto.dart';

import '../finding.dart';
import '../severity.dart';

/// Classifies delivery-cadence signals: a declining commit trend, commit
/// inequality across authors (Gini), and sustained off-hours (burnout
/// window) work.
class CommitVelocityClassifier {
  const CommitVelocityClassifier();

  /// Compact citation tag carried inline on every finding.
  static const String researchBasis =
      'Cadence, commit inequality, off-hours work (Gini 1912; Claes et al. '
      '2018)';

  /// Fuller research rationale carried only in the offloaded full report.
  static const String researchRationale =
      'Commit inequality is measured with the Gini coefficient (Gini, 1912) '
      '— high concentration means delivery depends on few people; sustained '
      'night/weekend commits correlate with unsustainable pace and burnout '
      '(Claes, Mens & Grosjean, ICSE 2018).';

  List<Finding> classify(CommitVelocityDto dto) {
    if (dto.totalCommits <= 0) return const [];
    final findings = <Finding>[];

    if (dto.trend == 'declining' && dto.velocitySlope < 0) {
      findings.add(Finding(
        category: 'velocity',
        source: 'analyze_commit_velocity',
        severity: Severity.elevated,
        subject: 'repository',
        metric: 'velocity_slope',
        value: double.parse(dto.velocitySlope.toStringAsFixed(3)),
        band: 'declining commit trend',
        basis: researchBasis,
        rationale: researchRationale,
        message: 'Commit velocity is declining '
            '(slope ${dto.velocitySlope.toStringAsFixed(2)} per period, '
            'avg ${dto.averagePerPeriod.toStringAsFixed(1)} commits).',
        evidence: {
          'trend': dto.trend,
          'average_per_period':
              double.parse(dto.averagePerPeriod.toStringAsFixed(2)),
          'total_commits': dto.totalCommits,
        },
      ));
    }

    if (dto.giniCoefficient > giniAuthorConcentrationHighThreshold) {
      final topAuthor = _topAuthorAcrossBuckets(dto.buckets);
      findings.add(Finding(
        category: 'velocity',
        source: 'analyze_commit_velocity',
        severity: Severity.high,
        subject: topAuthor ?? 'repository',
        metric: 'gini_coefficient',
        value: double.parse(dto.giniCoefficient.toStringAsFixed(3)),
        band: '> $giniAuthorConcentrationHighThreshold Gini author '
            'concentration',
        basis: researchBasis,
        rationale: researchRationale,
        message: 'Commit activity is concentrated '
            '(Gini ${dto.giniCoefficient.toStringAsFixed(2)}'
            '${topAuthor != null ? ', led by $topAuthor' : ''}) — delivery '
            'depends on very few people.',
        evidence: {
          'gini_coefficient':
              double.parse(dto.giniCoefficient.toStringAsFixed(3)),
          if (topAuthor != null) 'top_author': topAuthor,
        },
      ));
    }

    final burnoutShare = dto.totalBurnoutCommits / dto.totalCommits;
    if (burnoutShare > burnoutCommitShareHighThreshold) {
      findings.add(Finding(
        category: 'velocity',
        source: 'analyze_commit_velocity',
        severity: Severity.high,
        subject: 'repository',
        metric: 'burnout_commit_share',
        value: double.parse(burnoutShare.toStringAsFixed(3)),
        band: '> ${(burnoutCommitShareHighThreshold * 100).toStringAsFixed(0)}'
            '% commits in the burnout window',
        basis: researchBasis,
        rationale: researchRationale,
        message: '${dto.totalBurnoutCommits} of ${dto.totalCommits} commits '
            '(${(burnoutShare * 100).toStringAsFixed(1)}%) land in the '
            'burnout window (nights/weekends).',
        evidence: {
          'total_burnout_commits': dto.totalBurnoutCommits,
          'total_commits': dto.totalCommits,
        },
      ));
    }

    return findings;
  }

  String? _topAuthorAcrossBuckets(List<TimeBucket> buckets) {
    final totals = <String, int>{};
    for (final bucket in buckets) {
      bucket.authors.forEach((author, count) {
        totals[author] = (totals[author] ?? 0) + count;
      });
    }
    if (totals.isEmpty) return null;
    return totals.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}
