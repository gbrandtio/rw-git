/// ----------------------------------------------------------------------------
/// complexity_classifier.dart
/// ----------------------------------------------------------------------------
library;

import '../models/analysis_type.dart';

import 'package:rw_git/src/models/advanced_code_quality_dto.dart';

import '../../source_file_filter.dart';
import '../models/finding.dart';
import '../utils/path_key.dart';
import '../utils/repo_stats.dart';
import '../models/severity.dart';

/// Classifies file complexity against the repository's own median. Complexity
/// here is a raw control-flow keyword count, not a normalised score, so an
/// absolute cut-off would be meaningless — the band is repo-relative.
class ComplexityClassifier {
  const ComplexityClassifier();

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
        source: [AnalysisType.codeQuality],
        severity: severity,
        subject: normalized,
        metric: 'file_complexity',
        value: complexity,
        band: band,
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
