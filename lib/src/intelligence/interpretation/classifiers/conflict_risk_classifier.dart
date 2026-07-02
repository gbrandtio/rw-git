/// ----------------------------------------------------------------------------
/// conflict_risk_classifier.dart
/// ----------------------------------------------------------------------------
library;

import '../finding.dart';
import '../path_key.dart';
import '../severity.dart';

/// Classifies merge-conflict risk between two branches, from the
/// `ConflictRiskHeuristic` output map: exact textual conflicts detected by
/// `git merge-tree` band High; files merely modified on both branches since
/// the merge base (logical overlap) band Elevated.
class ConflictRiskClassifier {
  const ConflictRiskClassifier();

  /// Compact citation tag carried inline on every finding.
  static const String researchBasis =
      'Early merge-conflict detection (Brun et al. 2011; Mens 2002)';

  /// Fuller research rationale carried only in the offloaded full report.
  static const String researchRationale =
      'Conflicts detected early are dramatically cheaper to resolve: most '
      'conflicts persist and compound the longer branches diverge (Brun, '
      'Holmes, Ernst & Notkin, FSE 2011); textual overlap is the primary '
      'merge hazard (Mens, TSE 2002).';

  List<Finding> classify(Map<String, List<String>> conflictRisk) {
    final textualConflicts =
        conflictRisk['textual_conflicting_files'] ?? const [];
    final logicalOverlaps = conflictRisk['conflicting_files'] ?? const [];
    final textualSet = textualConflicts.map(PathKey.normalize).toSet();

    final findings = <Finding>[];
    for (final file in textualConflicts) {
      final normalized = PathKey.normalize(file);
      findings.add(Finding(
        category: 'conflictRisk',
        source: 'predict_merge_conflicts',
        severity: Severity.high,
        subject: normalized,
        metric: 'textual_conflict',
        value: 'conflict',
        band: 'textual merge conflict (git merge-tree)',
        basis: researchBasis,
        rationale: researchRationale,
        message: '$normalized will conflict textually when the branches '
            'merge.',
      ));
    }

    for (final file in logicalOverlaps) {
      final normalized = PathKey.normalize(file);
      // A file with an exact textual conflict already carries the stronger
      // finding; repeating it as a logical overlap would only add noise.
      if (textualSet.contains(normalized)) continue;
      findings.add(Finding(
        category: 'conflictRisk',
        source: 'predict_merge_conflicts',
        severity: Severity.elevated,
        subject: normalized,
        metric: 'logical_overlap',
        value: 'overlap',
        band: 'modified on both branches since merge base',
        basis: researchBasis,
        rationale: researchRationale,
        message: '$normalized was modified on both branches since their '
            'merge base — review the merge closely.',
      ));
    }
    return findings;
  }
}
