/// ----------------------------------------------------------------------------
/// commit_velocity_classifier.dart
/// ----------------------------------------------------------------------------
library;

import '../models/analysis_type.dart';

import 'package:rw_git/src/constants.dart';
import 'package:rw_git/src/models/commit_velocity_dto.dart';

import '../models/finding.dart';
import '../models/severity.dart';

/// Classifies delivery-cadence signals: a declining commit trend, commit
/// inequality across authors (Gini), and sustained off-hours (burnout
/// window) work.
class CommitVelocityClassifier {
  const CommitVelocityClassifier();

  List<Finding> classify(CommitVelocityDto dto) {
    if (dto.totalCommits <= 0) return const [];
    final findings = <Finding>[];

    if (dto.trend == 'declining' && dto.velocitySlope < 0) {
      findings.add(Finding(
        category: 'velocity',
        source: [AnalysisType.commitVelocity],
        severity: Severity.elevated,
        subject: 'repository',
        metric: 'velocity_slope',
        value: double.parse(dto.velocitySlope.toStringAsFixed(3)),
        band: 'declining commit trend',
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
        source: [AnalysisType.commitVelocity],
        severity: Severity.high,
        subject: topAuthor ?? 'repository',
        metric: 'gini_coefficient',
        value: double.parse(dto.giniCoefficient.toStringAsFixed(3)),
        band: '> $giniAuthorConcentrationHighThreshold Gini author '
            'concentration',
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
        source: [AnalysisType.commitVelocity],
        severity: Severity.high,
        subject: 'repository',
        metric: 'burnout_commit_share',
        value: double.parse(burnoutShare.toStringAsFixed(3)),
        band: '> ${(burnoutCommitShareHighThreshold * 100).toStringAsFixed(0)}'
            '% commits in the burnout window',
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
