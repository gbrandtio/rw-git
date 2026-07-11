/// ----------------------------------------------------------------------------
/// volatility_classifier.dart
/// ----------------------------------------------------------------------------
library;

import '../models/analysis_type.dart';

import 'package:rw_git/src/models/code_volatility_dto.dart';

import '../models/finding.dart';
import '../utils/path_key.dart';
import '../utils/repo_stats.dart';
import '../models/severity.dart';

/// Flags the most volatile files (high churn x many authors) as a supporting
/// defect-risk signal.
class VolatilityClassifier {
  const VolatilityClassifier();

  List<Finding> classify(List<CodeVolatilityDto> files) {
    if (files.isEmpty) return const [];
    final threshold = RepoStats.topDecileThreshold(
      files.map((f) => f.volatilityScore),
    );
    if (threshold <= 0) return const [];

    final findings = <Finding>[];
    for (final f in files) {
      if (f.volatilityScore < threshold) continue;
      final normalized = PathKey.normalize(f.filePath);
      final score = double.parse(f.volatilityScore.toStringAsFixed(2));
      findings.add(
        Finding(
          category: 'volatility',
          source: [AnalysisType.codeVolatility],
          severity: Severity.elevated,
          subject: normalized,
          metric: 'volatility_score',
          value: score,
          band: 'top-decile volatility',
          evidence: {
            'total_changes': f.totalChanges,
            'unique_authors': f.uniqueAuthors,
            'volatility_score': score,
          },
        ),
      );
    }
    return findings;
  }
}
