import 'package:rw_git/src/core/process_runner.dart';
import 'package:rw_git/src/models/bug_hotspot_dto.dart';
import '../algorithms/szz_algorithm.dart';

/// ----------------------------------------------------------------------------
/// bug_hotspots_heuristic.dart
/// ----------------------------------------------------------------------------
class BugHotspotsHeuristic {
  final ProcessRunner runner;

  BugHotspotsHeuristic(this.runner);

  /// Identifies files most frequently modified in bug-fix commits
  /// and the authors most frequently responsible for introducing bugs.
  Future<BugHotspotDto> calculateBugHotspots(String directory,
      {String? limit}) async {
    final matches = await SzzAlgorithm(runner).execute(directory, limit: limit);

    final fileHotspots = <String, int>{};
    final authorHotspots = <String, int>{};
    final fileTime = <String, List<int>>{};
    final authorTime = <String, List<int>>{};
    final uniqueFixCommits = <String>{};
    int totalFixTime = 0;
    int fixTimeCount = 0;

    for (final match in matches) {
      final hours =
          match.fixingDate.difference(match.introducingDate).inHours.abs();

      uniqueFixCommits.add(match.fixingCommitHash);

      fileHotspots[match.filePath] = (fileHotspots[match.filePath] ?? 0) + 1;
      fileTime.putIfAbsent(match.filePath, () => []).add(hours);

      final author = match.introducingAuthor;
      authorHotspots[author] = (authorHotspots[author] ?? 0) + 1;
      authorTime.putIfAbsent(author, () => []).add(hours);

      totalFixTime += hours;
      fixTimeCount++;
    }

    final globalAvg = fixTimeCount > 0 ? totalFixTime / fixTimeCount : 0.0;

    final fileAvg = <String, double>{};
    for (final entry in fileTime.entries) {
      final sum = entry.value.fold<int>(0, (a, b) => a + b);
      fileAvg[entry.key] = sum / entry.value.length;
    }

    final authorAvg = <String, double>{};
    for (final entry in authorTime.entries) {
      final sum = entry.value.fold<int>(0, (a, b) => a + b);
      authorAvg[entry.key] = sum / entry.value.length;
    }

    return BugHotspotDto(
      fileHotspots: fileHotspots,
      authorHotspots: authorHotspots,
      totalFixCommitsAnalyzed: uniqueFixCommits.length,
      globalAverageTimeToFixInHours: globalAvg,
      fileAverageTimeToFixInHours: fileAvg,
      authorAverageTimeToFixInHours: authorAvg,
    );
  }
}
