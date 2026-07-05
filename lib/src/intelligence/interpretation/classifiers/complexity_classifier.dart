/// ----------------------------------------------------------------------------
/// complexity_classifier.dart
/// ----------------------------------------------------------------------------
library;

import 'package:rw_git/src/models/advanced_code_quality_dto.dart';

import '../../source_file_filter.dart';
import '../finding.dart';
import '../path_key.dart';
import '../repo_stats.dart';
import '../severity.dart';

/// Classifies file complexity against the repository's own median. Complexity
/// here is a raw control-flow keyword count, not a normalised score, so an
/// absolute cut-off would be meaningless — the band is repo-relative.
class ComplexityClassifier {
  const ComplexityClassifier();

  /// Compact citation tag carried inline on every finding.
  static const String researchBasis =
      'Control-flow keyword proxy, repo-relative bands (McCabe 1976)';

  /// Fuller research rationale carried only in the offloaded full report.
  static const String researchRationale =
      'Counts control-flow keywords on changed lines as a lightweight proxy '
      'for cyclomatic complexity (McCabe, IEEE TSE 1976). The count is not a '
      'normalised score, so bands compare each file against the '
      'repository\'s own median rather than an absolute cut-off.';

  List<Finding> classify(AdvancedCodeQualityDto dto) {
    // The keyword proxy matches English prose too, so non-source files
    // (SourceFileFilter) are dropped before the median: they are not valid
    // complexity subjects and would skew the repo-relative band for code.
    final complexities = <String, int>{
      for (final entry in dto.fileComplexity.entries)
        if (SourceFileFilter.isSource(entry.key)) entry.key: entry.value,
    };
    if (complexities.isEmpty) return const [];
    final median = RepoStats.median(complexities.values);
    if (median <= 0) return const [];

    final findings = <Finding>[];
    complexities.forEach((file, complexity) {
      final ratio = complexity / median;
      final Severity severity;
      final String band;
      if (ratio > 2) {
        severity = Severity.high;
        band = '> 2x repo median complexity';
      } else if (ratio > 1) {
        severity = Severity.elevated;
        band = '1-2x repo median complexity';
      } else {
        return;
      }

      final normalized = PathKey.normalize(file);
      findings.add(Finding(
        category: 'complexity',
        source: 'analyze_code_quality',
        severity: severity,
        subject: normalized,
        metric: 'file_complexity',
        value: complexity,
        band: band,
        basis: researchBasis,
        rationale: researchRationale,
        message: 'High complexity in $normalized: $complexity control-flow '
            'keywords (${ratio.toStringAsFixed(1)}x repo median '
            '${median.toStringAsFixed(1)}).',
        evidence: {
          'file_complexity': complexity,
          'repo_median': double.parse(median.toStringAsFixed(2)),
          'ratio_to_median': double.parse(ratio.toStringAsFixed(2)),
        },
      ));
    });
    return findings;
  }
}
