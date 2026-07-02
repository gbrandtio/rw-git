/// ----------------------------------------------------------------------------
/// volatility_classifier.dart
/// ----------------------------------------------------------------------------
library;

import 'package:rw_git/src/models/code_volatility_dto.dart';

import '../finding.dart';
import '../path_key.dart';
import '../repo_stats.dart';
import '../severity.dart';

/// Flags the most volatile files (high churn x many authors) as a supporting
/// defect-risk signal.
class VolatilityClassifier {
  const VolatilityClassifier();

  /// Compact citation tag carried inline on every finding.
  static const String researchBasis =
      'Churn x authors defect prediction (Nagappan & Ball 2005; Weyuker '
      '2008)';

  /// Fuller research rationale carried only in the offloaded full report.
  static const String researchRationale =
      'High change volume combined with many distinct authors predicts '
      'fault-proneness beyond churn alone (Nagappan & Ball, ICSE 2005; '
      'Weyuker, Ostrand & Bell, Empirical SE 2008).';

  List<Finding> classify(List<CodeVolatilityDto> files) {
    if (files.isEmpty) return const [];
    final threshold =
        RepoStats.topDecileThreshold(files.map((f) => f.volatilityScore));
    if (threshold <= 0) return const [];

    final findings = <Finding>[];
    for (final f in files) {
      if (f.volatilityScore < threshold) continue;
      final normalized = PathKey.normalize(f.filePath);
      final score = double.parse(f.volatilityScore.toStringAsFixed(2));
      findings.add(Finding(
        category: 'volatility',
        source: 'analyze_code_volatility',
        severity: Severity.elevated,
        subject: normalized,
        metric: 'volatility_score',
        value: score,
        band: 'top-decile volatility',
        basis: researchBasis,
        rationale: researchRationale,
        message: '$normalized is highly volatile '
            '(${f.totalChanges} changes, ${f.uniqueAuthors} authors).',
        evidence: {
          'total_changes': f.totalChanges,
          'unique_authors': f.uniqueAuthors,
          'volatility_score': score,
        },
      ));
    }
    return findings;
  }
}
