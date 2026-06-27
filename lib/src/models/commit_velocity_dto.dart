/// Immutable DTO for time-bucketed commit velocity data.

class CommitVelocityDto {
  final List<TimeBucket> buckets;
  final int totalCommits;
  final double averagePerPeriod;
  final String trend;
  final List<TimeBucket> anomalies;

  const CommitVelocityDto({
    required this.buckets,
    required this.totalCommits,
    required this.averagePerPeriod,
    required this.trend,
    required this.anomalies,
  });
}

class TimeBucket {
  final String period;
  final int totalCommits;
  final Map<String, int> authors;

  const TimeBucket({
    required this.period,
    required this.totalCommits,
    required this.authors,
  });
}
