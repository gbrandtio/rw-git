// Immutable DTO for time-bucketed commit velocity data.

class CommitVelocityDto {
  final List<TimeBucket> buckets;
  final int totalCommits;
  final double averagePerPeriod;
  final String trend;
  final List<TimeBucket> anomalies;
  final int totalBurnoutCommits;

  /// Gini coefficient [0, 1] measuring commit inequality across authors.
  /// 0 = perfectly equal; 1 = one author does all commits.
  final double giniCoefficient;

  /// Slope of the linear regression line fitted to bucket commit counts.
  /// Positive = commits are increasing over time; negative = decreasing.
  final double velocitySlope;

  const CommitVelocityDto({
    required this.buckets,
    required this.totalCommits,
    required this.averagePerPeriod,
    required this.trend,
    required this.anomalies,
    required this.totalBurnoutCommits,
    required this.giniCoefficient,
    required this.velocitySlope,
  });
}

class TimeBucket {
  final String period;
  final int totalCommits;
  final Map<String, int> authors;
  final int burnoutCommits;

  const TimeBucket({
    required this.period,
    required this.totalCommits,
    required this.authors,
    required this.burnoutCommits,
  });
}
