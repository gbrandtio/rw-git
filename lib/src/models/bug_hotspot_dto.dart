class BugHotspotDto {
  /// The files that are frequently modified to fix bugs.
  final Map<String, int> fileHotspots;

  /// The authors who originally introduced the bugs.
  final Map<String, int> authorHotspots;

  /// Total number of bug-fixing commits analyzed.
  final int totalFixCommitsAnalyzed;

  BugHotspotDto({
    required this.fileHotspots,
    required this.authorHotspots,
    required this.totalFixCommitsAnalyzed,
  });

  Map<String, dynamic> toJson() {
    return {
      'file_hotspots': fileHotspots,
      'author_hotspots': authorHotspots,
      'total_fix_commits_analyzed': totalFixCommitsAnalyzed,
    };
  }
}
