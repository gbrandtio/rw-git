/// ----------------------------------------------------------------------------
/// churn_metrics_with_authors_dto.dart
/// ----------------------------------------------------------------------------
/// A model representation of the code churn metrics across a git repository,
/// including author contributions.

/// Represents statistics for a single entity (file, class, or block),
/// including total churn and a breakdown by author.
class ContributionStats {
  final int total;
  final Map<String, int> authors;

  const ContributionStats({
    required this.total,
    required this.authors,
  });
}

class ChurnMetricsWithAuthorsDto {
  final Map<String, ContributionStats> fileChurn;
  final Map<String, ContributionStats> classChurn;
  final Map<String, ContributionStats> blockChurn;
  final int totalCommits;

  const ChurnMetricsWithAuthorsDto({
    required this.fileChurn,
    required this.classChurn,
    required this.blockChurn,
    required this.totalCommits,
  });

  /// Factory constructor returning an empty instance.
  factory ChurnMetricsWithAuthorsDto.empty() {
    return const ChurnMetricsWithAuthorsDto(
      fileChurn: {},
      classChurn: {},
      blockChurn: {},
      totalCommits: 0,
    );
  }
}
