/// ----------------------------------------------------------------------------
/// commit_hygiene_classifier.dart
/// ----------------------------------------------------------------------------
library;

import 'package:rw_git/src/constants.dart';

import '../finding.dart';
import '../severity.dart';

/// Classifies commit-hygiene signals for the repository audit: oversized
/// ("mega") commits and commits with suspicious messages. Follows the
/// compliance classifier's aggregate pattern — one finding per family with
/// a bounded evidence sample — so a repo with hundreds of hits does not
/// flood the ranked findings.
class CommitHygieneClassifier {
  const CommitHygieneClassifier();

  /// Compact citation tag carried inline on every finding.
  static const String researchBasis =
      'Change-set size and intent signals (Nagappan & Ball 2005; Mockus & '
      'Votta 2000)';

  /// Fuller research rationale carried only in the offloaded full report.
  static const String researchRationale =
      'Large change sets are disproportionately defect-prone and hard to '
      'review (Nagappan & Ball, ICSE 2005); commit messages reliably encode '
      'change intent, so suspicious wording flags risky changes (Mockus & '
      'Votta, ICSM 2000).';

  /// [megaCommits] are the formatted `hash - author (date): message` lines
  /// produced by `MegaCommitsHeuristic.findMegaCommits`.
  List<Finding> classifyMegaCommits(List<String> megaCommits) =>
      _aggregate(megaCommits, metric: 'mega_commits', label: 'mega commit(s)');

  /// [suspiciousCommits] are the formatted lines produced by
  /// `SuspiciousCommitsHeuristic.findSuspiciousCommits`.
  List<Finding> classifySuspiciousCommits(List<String> suspiciousCommits) =>
      _aggregate(suspiciousCommits,
          metric: 'suspicious_commits', label: 'suspicious commit(s)');

  List<Finding> _aggregate(List<String> flaggedCommits,
      {required String metric, required String label}) {
    if (flaggedCommits.isEmpty) return const [];
    return [
      Finding(
        category: 'commitHygiene',
        source: 'analyze_code_quality',
        severity: Severity.moderate,
        subject: 'repository',
        metric: metric,
        value: flaggedCommits.length,
        band: '${flaggedCommits.length} $label',
        basis: researchBasis,
        rationale: researchRationale,
        message: '${flaggedCommits.length} $label detected in the analysed '
            'history.',
        evidence: {
          'count': flaggedCommits.length,
          'samples':
              flaggedCommits.take(aggregateFindingEvidenceSampleSize).toList(),
        },
      ),
    ];
  }
}
