class BugHotspotDto {
  /// The files that are frequently modified to fix bugs.
  final Map<String, int> fileHotspots;

  /// The authors who originally introduced the bugs.
  final Map<String, int> authorHotspots;

  /// Total number of bug-fixing commits analyzed.
  final int totalFixCommitsAnalyzed;

  /// The average time taken to fix bugs in the repository (in hours).
  final double globalAverageTimeToFixInHours;

  /// The average time taken to fix bugs per file (in hours).
  final Map<String, double> fileAverageTimeToFixInHours;

  /// The average time taken to fix bugs introduced by specific authors (in hours).
  final Map<String, double> authorAverageTimeToFixInHours;

  BugHotspotDto({
    required this.fileHotspots,
    required this.authorHotspots,
    required this.totalFixCommitsAnalyzed,
    required this.globalAverageTimeToFixInHours,
    required this.fileAverageTimeToFixInHours,
    required this.authorAverageTimeToFixInHours,
  });

  Map<String, dynamic> toJson() {
    return {
      'file_hotspots': fileHotspots,
      'author_hotspots': authorHotspots,
      'total_fix_commits_analyzed': totalFixCommitsAnalyzed,
      'global_average_time_to_fix_in_hours': globalAverageTimeToFixInHours,
      'file_average_time_to_fix_in_hours': fileAverageTimeToFixInHours,
      'author_average_time_to_fix_in_hours': authorAverageTimeToFixInHours,
    };
  }
}
