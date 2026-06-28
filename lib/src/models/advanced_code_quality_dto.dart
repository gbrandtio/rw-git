class AdvancedCodeQualityDto {
  /// Complexity measured by counting control flow keywords (if, for, while, etc.)
  final Map<String, int> fileComplexity;

  /// Matrix mapping a file to other files it frequently changes with (Blast Radius / SRP)
  final Map<String, Map<String, int>> coChangeMatrix;

  /// Churn frequency of specific methods/blocks (OCP Violations)
  final Map<String, int> methodChurn;

  /// Distribution of commits across top-level directories (Architecture Drift)
  final Map<String, double> architectureDistribution;

  AdvancedCodeQualityDto({
    required this.fileComplexity,
    required this.coChangeMatrix,
    required this.methodChurn,
    required this.architectureDistribution,
  });

  Map<String, dynamic> toJson() {
    return {
      'file_complexity': fileComplexity,
      'co_change_matrix': coChangeMatrix,
      'method_churn': methodChurn,
      'architecture_distribution': architectureDistribution,
    };
  }
}
