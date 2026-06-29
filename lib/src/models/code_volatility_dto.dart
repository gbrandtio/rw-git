/// code_volatility_dto.dart
class CodeVolatilityDto {
  final String filePath;
  final int totalChanges;
  final int uniqueAuthors;
  final double volatilityScore;

  CodeVolatilityDto({
    required this.filePath,
    required this.totalChanges,
    required this.uniqueAuthors,
    required this.volatilityScore,
  });

  Map<String, dynamic> toJson() {
    return {
      'file_path': filePath,
      'total_changes': totalChanges,
      'unique_authors': uniqueAuthors,
      'volatility_score': volatilityScore.toStringAsFixed(2),
    };
  }
}
