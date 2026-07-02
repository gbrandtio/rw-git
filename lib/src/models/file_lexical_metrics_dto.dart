/// file_lexical_metrics_dto.dart
/// Per-file genuine lexical metrics computed by the bounded report-grade
/// sampler: McCabe cyclomatic complexity and the maintainability index for
/// one source file, keyed by its repository-relative path so the
/// interpretation layer can join it with churn/hotspot findings.
class FileLexicalMetricsDto {
  /// Repository-relative path exactly as it appears in the churn metrics,
  /// so `PathKey.normalize` yields the same join key across classifiers.
  final String filePath;

  /// Genuine McCabe cyclomatic complexity of the whole file (McCabe 1976).
  final int cyclomaticComplexity;

  /// Maintainability index score, 0-100 (Coleman et al. 1994).
  final double maintainabilityIndex;

  const FileLexicalMetricsDto({
    required this.filePath,
    required this.cyclomaticComplexity,
    required this.maintainabilityIndex,
  });

  Map<String, dynamic> toJson() => {
        'file_path': filePath,
        'cyclomatic_complexity': cyclomaticComplexity,
        'maintainability_index': maintainabilityIndex,
      };
}
