class AdvancedCodeQualityDto {
  /// Complexity measured by counting control flow keywords (if, for, while, etc.)
  final Map<String, int> fileComplexity;

  /// Matrix mapping a file to other files it frequently changes with (Blast Radius / SRP)
  final Map<String, Map<String, int>> coChangeMatrix;

  /// Distribution of commits across top-level directories (Architecture Drift)
  final Map<String, double> architectureDistribution;

  AdvancedCodeQualityDto({
    required this.fileComplexity,
    required this.coChangeMatrix,
    required this.architectureDistribution,
  });

  Map<String, dynamic> toJson() {
    return {
      'file_complexity': fileComplexity,
      'co_change_matrix': coChangeMatrix,
      'architecture_distribution': architectureDistribution,
    };
  }
}
