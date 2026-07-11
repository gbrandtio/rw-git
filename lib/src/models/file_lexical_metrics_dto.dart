/// file_lexical_metrics_dto.dart
/// Per-file genuine lexical metrics computed by the bounded report-grade
/// sampler: the full research-backed complexity suite for one source file,
/// keyed by its repository-relative path so the interpretation layer can
/// join it with churn/hotspot findings.
class FileLexicalMetricsDto {
  /// Repository-relative path exactly as it appears in the churn metrics,
  /// so `PathKey.normalize` yields the same join key across classifiers.
  final String filePath;

  /// Genuine McCabe cyclomatic complexity of the whole file (McCabe 1976).
  final int cyclomaticComplexity;

  /// Maintainability index score, 0-100 (Coleman et al. 1994).
  final double maintainabilityIndex;

  /// ABC score magnitude: sqrt(assignments² + branches² + conditions²)
  /// (Fitzpatrick 1997).
  final double abcScore;

  /// NPath acyclic execution path estimate, ~2^decisions (Nejmeh 1988).
  final int npathComplexity;

  /// Cognitive complexity, nesting-weighted understandability cost
  /// (Campbell 2018).
  final int cognitiveComplexity;

  /// Halstead delivered-bugs estimate, volume / 3000 (Halstead 1977).
  final double halsteadDeliveredBugs;

  const FileLexicalMetricsDto({
    required this.filePath,
    required this.cyclomaticComplexity,
    required this.maintainabilityIndex,
    required this.abcScore,
    required this.npathComplexity,
    required this.cognitiveComplexity,
    required this.halsteadDeliveredBugs,
  });

  Map<String, dynamic> toJson() => {
        'file_path': filePath,
        'cyclomatic_complexity': cyclomaticComplexity,
        'maintainability_index': maintainabilityIndex,
        'abc_score': abcScore,
        'npath_complexity': npathComplexity,
        'cognitive_complexity': cognitiveComplexity,
        'halstead_delivered_bugs': halsteadDeliveredBugs,
      };
}
