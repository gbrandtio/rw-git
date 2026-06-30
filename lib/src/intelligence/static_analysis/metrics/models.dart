/// Encapsulates the results of Halstead Complexity algorithms.
class HalsteadResult {
  final int vocabulary;
  final int length;
  final double volume;
  final double difficulty;
  final double effort;
  final double timeRequired;
  final double deliveredBugs;

  const HalsteadResult({
    required this.vocabulary,
    required this.length,
    required this.volume,
    required this.difficulty,
    required this.effort,
    required this.timeRequired,
    required this.deliveredBugs,
  });

  Map<String, dynamic> toJson() => {
        'vocabulary': vocabulary,
        'length': length,
        'volume': volume,
        'difficulty': difficulty,
        'effort': effort,
        'timeRequired': timeRequired,
        'deliveredBugs': deliveredBugs,
      };
}

/// Encapsulates the results of the composite Maintainability Index algorithm.
class MaintainabilityResult {
  final double score;
  final String category; // e.g., 'Highly Maintainable', 'Moderate', 'Low'

  const MaintainabilityResult({
    required this.score,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
        'score': score,
        'category': category,
      };
}
