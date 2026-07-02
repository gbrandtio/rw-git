class BugHotspotDto {
  /// The files that are frequently modified to fix bugs.
  final Map<String, int> fileHotspots;

  /// The authors who originally introduced the bugs.
  final Map<String, int> authorHotspots;

  /// Total number of bug-fixing commits analyzed.
  final int totalFixCommitsAnalyzed;

  /// The average bug lifetime across the repository, in days.
  ///
  /// SZZ measures the span from the bug-*introducing* commit to the
  /// bug-*fixing* commit ("bug lifetime" in the SZZ literature), not the
  /// effort spent fixing once the bug was noticed. Lifetimes of weeks or
  /// months are normal for mature repositories.
  final double globalAverageBugLifetimeInDays;

  /// The average bug lifetime per file, in days (see
  /// [globalAverageBugLifetimeInDays] for the semantics).
  final Map<String, double> fileAverageBugLifetimeInDays;

  /// The average lifetime of bugs introduced by each author, in days (see
  /// [globalAverageBugLifetimeInDays] for the semantics).
  final Map<String, double> authorAverageBugLifetimeInDays;

  BugHotspotDto({
    required this.fileHotspots,
    required this.authorHotspots,
    required this.totalFixCommitsAnalyzed,
    required this.globalAverageBugLifetimeInDays,
    required this.fileAverageBugLifetimeInDays,
    required this.authorAverageBugLifetimeInDays,
  });

  Map<String, dynamic> toJson() {
    return {
      'file_hotspots': fileHotspots,
      'author_hotspots': authorHotspots,
      'total_fix_commits_analyzed': totalFixCommitsAnalyzed,
      'global_average_bug_lifetime_in_days': globalAverageBugLifetimeInDays,
      'file_average_bug_lifetime_in_days': fileAverageBugLifetimeInDays,
      'author_average_bug_lifetime_in_days': authorAverageBugLifetimeInDays,
    };
  }
}
