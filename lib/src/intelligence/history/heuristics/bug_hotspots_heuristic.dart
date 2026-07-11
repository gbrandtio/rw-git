import 'package:rw_git/src/constants.dart';
import 'package:rw_git/src/models/bug_hotspot_dto.dart';
import '../algorithms/szz_algorithm.dart';

/// ----------------------------------------------------------------------------
/// bug_hotspots_heuristic.dart
/// ----------------------------------------------------------------------------
class BugHotspotsHeuristic {
  /// Identifies files most frequently modified in bug-fix commits
  /// and the authors most frequently responsible for introducing bugs.
  ///
  /// Pure aggregation over an already-fetched [SzzAlgorithm] match list, so
  /// callers control the single shared SZZ invocation (and any
  /// author/regex filtering of it) without this class needing I/O access.
  BugHotspotDto aggregate(List<SzzMatch> matches) {
    final fileHotspots = <String, int>{};
    final authorHotspots = <String, int>{};
    final fileLifetimes = <String, List<double>>{};
    final authorLifetimes = <String, List<double>>{};
    final uniqueFixCommits = <String>{};
    double totalLifetimeDays = 0;
    int lifetimeCount = 0;

    for (final match in matches) {
      // SZZ bug lifetime: introducing commit → fixing commit. Minutes are
      // converted to fractional days because lifetimes routinely span weeks
      // or months; whole-hour truncation would be false precision.
      final lifetimeDays =
          match.fixingDate.difference(match.introducingDate).inMinutes.abs() /
          minutesPerDay;

      uniqueFixCommits.add(match.fixingCommitHash);

      fileHotspots[match.filePath] = (fileHotspots[match.filePath] ?? 0) + 1;
      fileLifetimes.putIfAbsent(match.filePath, () => []).add(lifetimeDays);

      final author = match.introducingAuthor;
      authorHotspots[author] = (authorHotspots[author] ?? 0) + 1;
      authorLifetimes.putIfAbsent(author, () => []).add(lifetimeDays);

      totalLifetimeDays += lifetimeDays;
      lifetimeCount++;
    }

    final globalAvg =
        lifetimeCount > 0 ? totalLifetimeDays / lifetimeCount : 0.0;

    final fileAvg = <String, double>{};
    for (final entry in fileLifetimes.entries) {
      final sum = entry.value.fold<double>(0, (a, b) => a + b);
      fileAvg[entry.key] = sum / entry.value.length;
    }

    final authorAvg = <String, double>{};
    for (final entry in authorLifetimes.entries) {
      final sum = entry.value.fold<double>(0, (a, b) => a + b);
      authorAvg[entry.key] = sum / entry.value.length;
    }

    return BugHotspotDto(
      fileHotspots: fileHotspots,
      authorHotspots: authorHotspots,
      totalFixCommitsAnalyzed: uniqueFixCommits.length,
      globalAverageBugLifetimeInDays: globalAvg,
      fileAverageBugLifetimeInDays: fileAvg,
      authorAverageBugLifetimeInDays: authorAvg,
    );
  }
}
