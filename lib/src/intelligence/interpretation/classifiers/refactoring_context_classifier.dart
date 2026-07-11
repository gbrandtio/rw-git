/// ----------------------------------------------------------------------------
/// refactoring_context_classifier.dart
/// ----------------------------------------------------------------------------
library;

import '../models/analysis_type.dart';

import 'package:rw_git/src/constants.dart';
import 'package:rw_git/src/models/refactoring_dto.dart';

import '../models/finding.dart';
import '../utils/path_key.dart';
import '../models/severity.dart';

/// Adds refactoring awareness to the technical report, two ways:
///
/// 1. [annotate] downgrades churn/volatility findings one band when the
///    file's changes are explained by detected refactorings — churn caused
///    by structural clean-up carries lower defect risk than feature churn
///    (the same insight behind RA-SZZ: Neto et al., SANER 2018).
/// 2. [classify] surfaces notable refactoring activity as a repo-level
///    tech-debt-paydown signal, so the report distinguishes intentional
///    clean-up from decay.
class RefactoringContextClassifier {
  const RefactoringContextClassifier();

  /// Categories whose findings are churn-derived and therefore softened
  /// when the underlying changes are refactorings.
  static const List<String> _churnDerivedCategories = ['churn', 'volatility'];

  /// Returns [findings] with churn-derived entries downgraded one band when
  /// their subject appears among [refactorings]' renamed files. Non-matching
  /// findings are returned unchanged; the list order is preserved.
  List<Finding> annotate(
    List<Finding> findings,
    List<RefactoringDto> refactorings,
  ) {
    if (refactorings.isEmpty) return findings;

    final refactoredCommitsByFile = <String, List<String>>{};
    for (final refactoring in refactorings) {
      for (final renamed in refactoring.renamedFiles) {
        refactoredCommitsByFile
            .putIfAbsent(PathKey.normalize(renamed), () => [])
            .add(refactoring.commitHash);
      }
    }
    if (refactoredCommitsByFile.isEmpty) return findings;

    return findings.map((finding) {
      if (!_churnDerivedCategories.contains(finding.category)) return finding;
      final refactoringCommits = refactoredCommitsByFile[finding.subject];
      if (refactoringCommits == null) return finding;
      return finding.copyWith(
        severity: _downgradeOneBand(finding.severity),
        band: '${finding.band} (partly explained by refactoring)',
        evidence: {
          ...finding.evidence,
          'refactoring_commits':
              refactoringCommits
                  .take(aggregateFindingEvidenceSampleSize)
                  .toList(),
        },
      );
    }).toList();
  }

  /// Emits a repo-level signal when refactoring activity is notable —
  /// deliberate tech-debt paydown a technical report should credit, not
  /// just risks.
  List<Finding> classify(List<RefactoringDto> refactorings) {
    if (refactorings.length < refactoringActivityNotableThreshold) {
      return const [];
    }
    final simplificationCount =
        refactorings.where((r) => r.isSimplification).length;
    return [
      Finding(
        category: 'refactoring',
        source: [AnalysisType.refactoring],
        severity: Severity.elevated,
        subject: 'repository',
        metric: 'refactoring_commits',
        value: refactorings.length,
        band: 'notable refactoring activity',
        evidence: {
          'refactoring_commits_detected': refactorings.length,
          'simplifications': simplificationCount,
          'sample_commits':
              refactorings
                  .take(aggregateFindingEvidenceSampleSize)
                  .map((r) => r.commitHash)
                  .toList(),
        },
      ),
    ];
  }

  Severity _downgradeOneBand(Severity severity) {
    const bandsDescending = [
      Severity.critical,
      Severity.high,
      Severity.moderate,
      Severity.elevated,
      Severity.low,
    ];
    final index = bandsDescending.indexOf(severity);
    if (index == -1 || index == bandsDescending.length - 1) return severity;
    return bandsDescending[index + 1];
  }
}
