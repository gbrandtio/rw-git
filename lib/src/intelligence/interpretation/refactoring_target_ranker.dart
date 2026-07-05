/// ----------------------------------------------------------------------------
/// refactoring_target_ranker.dart
/// ----------------------------------------------------------------------------
/// Tornhill's hotspot prioritization (Tornhill, "Your Code as a Crime
/// Scene", 2015): rank files by churn percentile x complexity percentile.
/// Faults concentrate in a small share of files (Ostrand, Weyuker & Bell
/// 2004), and complex code that also changes often is where refactoring
/// effort pays off most — a rarely-touched complex file costs little, and
/// a simple hot file needs no redesign. The ranked list turns the reports'
/// per-file boolean joins into an ordered "refactor these first" answer.
library;

import '../../constants.dart';
import '../../models/file_lexical_metrics_dto.dart';
import '../source_file_filter.dart';
import 'path_key.dart';

/// One ranked refactoring candidate: a file scored by how strongly its
/// change frequency and complexity intersect.
class RefactoringTarget {
  final String filePath;

  /// Churn percentile x complexity percentile, in (0, 1].
  final double riskScore;

  final int churn;
  final double churnPercentile;

  /// Which complexity measurement scored this file: genuine
  /// `cyclomatic_complexity` when the file was in the bounded lexical
  /// sample, else the repo-relative `complexity_proxy`.
  final String complexityMetric;
  final num complexityValue;
  final double complexityPercentile;

  const RefactoringTarget({
    required this.filePath,
    required this.riskScore,
    required this.churn,
    required this.churnPercentile,
    required this.complexityMetric,
    required this.complexityValue,
    required this.complexityPercentile,
  });

  Map<String, dynamic> toJson() => {
        'file_path': filePath,
        'risk_score': double.parse(riskScore.toStringAsFixed(3)),
        'churn': churn,
        'churn_percentile': double.parse(churnPercentile.toStringAsFixed(3)),
        'complexity_metric': complexityMetric,
        'complexity_value': complexityValue,
        'complexity_percentile':
            double.parse(complexityPercentile.toStringAsFixed(3)),
      };
}

/// Ranks refactoring targets from the churn and complexity data a report
/// run already computed — no additional git calls or file reads.
class RefactoringTargetRanker {
  const RefactoringTargetRanker();

  /// Compact citation tag carried on the ranked list.
  static const String researchBasis =
      'Hotspot prioritization (Tornhill 2015; Ostrand, Weyuker & Bell 2004)';

  /// Scores every source-code file appearing in both [fileChurn] and a
  /// complexity source. Non-source files ([SourceFileFilter]) are dropped
  /// from every population before percentiling — hotspot analysis is
  /// defined over code, and prose files match the keyword proxy while
  /// distorting churn percentiles for everything else. Genuine McCabe from
  /// [lexicalMetrics] is preferred; files outside the bounded lexical
  /// sample fall back to the [proxyComplexity] keyword counts, each
  /// percentiled within its own population so the two scales never mix.
  /// Returns at most [maxRefactoringTargets] targets with a risk score of
  /// at least [refactoringTargetMinimumRiskScore], highest first.
  List<RefactoringTarget> rank({
    required Map<String, int> fileChurn,
    Map<String, int> proxyComplexity = const {},
    List<FileLexicalMetricsDto> lexicalMetrics = const [],
  }) {
    if (fileChurn.isEmpty) return const [];

    final churnByFile = <String, int>{
      for (final entry in fileChurn.entries)
        if (SourceFileFilter.isSource(entry.key))
          PathKey.normalize(entry.key): entry.value,
    };
    if (churnByFile.isEmpty) return const [];
    final churnPercentiles = _percentiles(churnByFile);

    final mccabeByFile = <String, int>{
      for (final metrics in lexicalMetrics)
        if (SourceFileFilter.isSource(metrics.filePath))
          PathKey.normalize(metrics.filePath): metrics.cyclomaticComplexity,
    };
    final mccabePercentiles = _percentiles(mccabeByFile);

    final proxyByFile = <String, int>{
      for (final entry in proxyComplexity.entries)
        if (SourceFileFilter.isSource(entry.key))
          PathKey.normalize(entry.key): entry.value,
    };
    final proxyPercentiles = _percentiles(proxyByFile);

    final targets = <RefactoringTarget>[];
    for (final entry in churnByFile.entries) {
      final file = entry.key;

      final String complexityMetric;
      final num complexityValue;
      final double complexityPercentile;
      if (mccabeByFile.containsKey(file)) {
        complexityMetric = 'cyclomatic_complexity';
        complexityValue = mccabeByFile[file]!;
        complexityPercentile = mccabePercentiles[file]!;
      } else if (proxyByFile.containsKey(file)) {
        complexityMetric = 'complexity_proxy';
        complexityValue = proxyByFile[file]!;
        complexityPercentile = proxyPercentiles[file]!;
      } else {
        continue;
      }

      final churnPercentile = churnPercentiles[file]!;
      final riskScore = churnPercentile * complexityPercentile;
      if (riskScore < refactoringTargetMinimumRiskScore) continue;

      targets.add(RefactoringTarget(
        filePath: file,
        riskScore: riskScore,
        churn: entry.value,
        churnPercentile: churnPercentile,
        complexityMetric: complexityMetric,
        complexityValue: complexityValue,
        complexityPercentile: complexityPercentile,
      ));
    }

    targets.sort((a, b) => b.riskScore.compareTo(a.riskScore));
    return targets.take(maxRefactoringTargets).toList();
  }

  /// Inclusive percentile of each value within its own population:
  /// share of values less than or equal to it, in (0, 1].
  static Map<String, double> _percentiles(Map<String, int> valuesByFile) {
    if (valuesByFile.isEmpty) return const {};
    final sortedValues = valuesByFile.values.toList()..sort();
    return {
      for (final entry in valuesByFile.entries)
        entry.key:
            _countAtMost(sortedValues, entry.value) / sortedValues.length,
    };
  }

  /// Number of elements in ascending [sortedValues] that are <= [value]
  /// (upper-bound binary search).
  static int _countAtMost(List<int> sortedValues, int value) {
    var low = 0;
    var high = sortedValues.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (sortedValues[mid] <= value) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }
}
