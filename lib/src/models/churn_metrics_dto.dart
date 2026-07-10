/// ----------------------------------------------------------------------------
/// churn_metrics_dto.dart
/// ----------------------------------------------------------------------------
/// A model representation of the code churn metrics across a git repository.
///
/// Provides maps representing the number of times files, classes, and code
/// blocks have been modified.
class ChurnMetricsDto {
  final Map<String, int> fileChurn;
  final int totalCommits;

  const ChurnMetricsDto({
    required this.fileChurn,
    required this.totalCommits,
  });

  /// Factory constructor returning an empty instance.
  factory ChurnMetricsDto.empty() {
    return const ChurnMetricsDto(
      fileChurn: {},
      totalCommits: 0,
    );
  }
}
