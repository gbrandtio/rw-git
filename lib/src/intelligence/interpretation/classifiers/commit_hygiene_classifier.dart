/// ----------------------------------------------------------------------------
/// commit_hygiene_classifier.dart
/// ----------------------------------------------------------------------------
library;

import '../models/analysis_type.dart';

import 'package:rw_git/src/constants.dart';

import '../models/finding.dart';
import '../models/severity.dart';

/// Classifies commit-hygiene signals for the repository audit: oversized
/// ("mega") commits and commits with suspicious messages. Follows the
/// compliance classifier's aggregate pattern — one finding per family with
/// a bounded evidence sample — so a repo with hundreds of hits does not
/// flood the ranked findings.
class CommitHygieneClassifier {
  const CommitHygieneClassifier();

  /// [megaCommits] are the formatted `hash - author (date): message` lines
  /// produced by `MegaCommitsHeuristic.findMegaCommits`.
  List<Finding> classifyMegaCommits(List<String> megaCommits) =>
      _aggregate(megaCommits, metric: 'mega_commits', label: 'mega commit(s)');

  /// [suspiciousCommits] are the formatted lines produced by
  /// `SuspiciousCommitsHeuristic.findSuspiciousCommits`.
  List<Finding> classifySuspiciousCommits(List<String> suspiciousCommits) =>
      _aggregate(
        suspiciousCommits,
        metric: 'suspicious_commits',
        label: 'suspicious commit(s)',
      );

  List<Finding> _aggregate(
    List<String> flaggedCommits, {
    required String metric,
    required String label,
  }) {
    if (flaggedCommits.isEmpty) return const [];
    return [
      Finding(
        category: 'commitHygiene',
        source: [AnalysisType.codeQuality],
        severity: Severity.moderate,
        subject: 'repository',
        metric: metric,
        value: flaggedCommits.length,
        band: '${flaggedCommits.length} $label',
        evidence: {
          'count': flaggedCommits.length,
          'samples': flaggedCommits
              .take(aggregateFindingEvidenceSampleSize)
              .toList(),
        },
      ),
    ];
  }
}
