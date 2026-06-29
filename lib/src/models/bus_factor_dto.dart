/// bus_factor_dto.dart
class BusFactorDto {
  final int busFactor;
  final int totalDevelopers;
  final List<DeveloperContribution> topContributors;

  BusFactorDto({
    required this.busFactor,
    required this.totalDevelopers,
    required this.topContributors,
  });

  Map<String, dynamic> toJson() {
    return {
      'bus_factor': busFactor,
      'total_developers_analyzed': totalDevelopers,
      'top_contributors': topContributors.map((e) => e.toJson()).toList(),
    };
  }
}

class DeveloperContribution {
  final String author;
  final int contributions; // can be commits or lines changed
  final double percentage;

  DeveloperContribution({
    required this.author,
    required this.contributions,
    required this.percentage,
  });

  Map<String, dynamic> toJson() {
    return {
      'author': author,
      'contributions': contributions,
      'percentage': (percentage * 100).toStringAsFixed(2),
    };
  }
}
