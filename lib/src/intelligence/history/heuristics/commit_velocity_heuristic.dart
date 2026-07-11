import 'dart:isolate';
import 'dart:math';
import 'package:rw_git/src/core/git_date_time.dart';
import 'package:rw_git/src/core/process_runner.dart';
import 'package:rw_git/src/models/commit_velocity_dto.dart';

/// ----------------------------------------------------------------------------
/// commit_velocity_heuristic.dart
/// ----------------------------------------------------------------------------
class CommitVelocityHeuristic {
  final ProcessRunner runner;

  CommitVelocityHeuristic(this.runner);

  /// Computes commit velocity over time, bucketed by the
  /// given granularity (day, week, or month).
  Future<CommitVelocityDto> calculateCommitVelocity(
    String directory, {
    String? limit,
    String? since,
    String? until,
    String granularity = 'week',
  }) async {
    final args = ['log', '--format=%H||%an||%aI'];
    if (limit != null) {
      args.insert(1, '-n');
      args.insert(2, limit);
    }
    if (since != null) {
      args.add('--since=$since');
    }
    if (until != null) {
      args.add('--until=$until');
    }

    final result = await runner.run('git', args, workingDirectory: directory);
    evaluateProcessResult(result);
    final rawOutput = result.stdout?.toString() ?? '';

    return await Isolate.run(
      () => _parseCommitVelocity(rawOutput, granularity),
    );
  }
}

CommitVelocityDto _parseCommitVelocity(String rawLog, String granularity) {
  final lines = rawLog.split('\n');
  final Map<String, Map<String, int>> bucketAuthors = {};
  final Map<String, int> bucketBurnout = {};

  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final parts = line.split('||');
    if (parts.length < 3) continue;

    final author = parts[1].trim();
    final dateStr = parts[2].trim();

    // Bucketing and burnout detection reason about the author's wall-clock
    // time (a 23:00 commit is late-night wherever the author sits), so the
    // timestamp's own UTC offset is honoured instead of converting to UTC
    // or to the machine-local timezone.
    final date = GitDateTime.parse(dateStr).authorLocal;

    String periodKey;
    switch (granularity) {
      case 'day':
        periodKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      case 'month':
        periodKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      case 'week':
      default:
        // ISO week: find the Monday of the week
        final weekday = date.weekday;
        final monday = date.subtract(Duration(days: weekday - 1));
        periodKey =
            '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
    }

    bucketAuthors.putIfAbsent(periodKey, () => {});
    bucketAuthors[periodKey]![author] =
        (bucketAuthors[periodKey]![author] ?? 0) + 1;

    // Detect burnout (commits outside 09:00 - 17:00)
    final isBurnout = date.hour < 9 || date.hour >= 17;
    if (isBurnout) {
      bucketBurnout[periodKey] = (bucketBurnout[periodKey] ?? 0) + 1;
    }
  }

  // Sort by period
  final sortedKeys = bucketAuthors.keys.toList()..sort();
  final buckets = <TimeBucket>[];
  final List<int> commitCounts = [];

  for (final key in sortedKeys) {
    final authors = bucketAuthors[key]!;
    final total = authors.values.fold<int>(0, (sum, v) => sum + v);
    final burnout = bucketBurnout[key] ?? 0;
    commitCounts.add(total);
    buckets.add(
      TimeBucket(
        period: key,
        totalCommits: total,
        authors: authors,
        burnoutCommits: burnout,
      ),
    );
  }

  final totalCommits = commitCounts.fold<int>(0, (sum, v) => sum + v);
  final avg = buckets.isEmpty ? 0.0 : totalCommits / buckets.length;

  // Determine trend from first half vs second half
  String trend = 'stable';
  if (buckets.length >= 4) {
    final mid = buckets.length ~/ 2;
    final firstHalfAvg =
        commitCounts.take(mid).fold<int>(0, (sum, v) => sum + v) / mid;
    final secondHalfAvg =
        commitCounts.skip(mid).fold<int>(0, (sum, v) => sum + v) /
            (buckets.length - mid);
    if (secondHalfAvg > firstHalfAvg * 1.2) {
      trend = 'accelerating';
    } else if (secondHalfAvg < firstHalfAvg * 0.8) {
      trend = 'decelerating';
    }
  }

  // Detect anomalies (> 2 standard deviations)
  final anomalies = <TimeBucket>[];
  if (commitCounts.length >= 3) {
    final mean = avg;
    final variance = commitCounts.fold<double>(
          0.0,
          (sum, v) => sum + (v - mean) * (v - mean),
        ) /
        commitCounts.length;
    final stdDev = sqrt(variance);
    final threshold = mean + 2 * stdDev;

    for (int i = 0; i < buckets.length; i++) {
      if (commitCounts[i] > threshold) {
        anomalies.add(buckets[i]);
      }
    }
  }

  final totalBurnoutCommits = buckets.fold<int>(
    0,
    (sum, b) => sum + b.burnoutCommits,
  );

  // Gini coefficient over all author commit totals (project-wide inequality).
  final Map<String, int> authorTotals = {};
  for (final bucket in buckets) {
    for (final entry in bucket.authors.entries) {
      authorTotals[entry.key] = (authorTotals[entry.key] ?? 0) + entry.value;
    }
  }
  final gini = _giniCoefficient(authorTotals.values.toList());

  // Linear regression slope over bucket commit counts.
  final slope = _linearRegressionSlope(commitCounts);

  return CommitVelocityDto(
    buckets: buckets,
    totalCommits: totalCommits,
    averagePerPeriod: avg,
    trend: trend,
    anomalies: anomalies,
    totalBurnoutCommits: totalBurnoutCommits,
    giniCoefficient: double.parse(gini.toStringAsFixed(3)),
    velocitySlope: double.parse(slope.toStringAsFixed(3)),
  );
}

/// Gini coefficient for a list of non-negative commit counts.
/// Returns 0.0 when the list is empty or all values are zero.
double _giniCoefficient(List<int> values) {
  if (values.isEmpty) return 0.0;
  final total = values.fold<int>(0, (s, v) => s + v);
  if (total == 0) return 0.0;
  final sampleCount = values.length;
  int sumAbsDiffs = 0;
  for (int i = 0; i < sampleCount; i++) {
    for (int j = 0; j < sampleCount; j++) {
      sumAbsDiffs += (values[i] - values[j]).abs();
    }
  }
  return sumAbsDiffs / (2.0 * sampleCount * total);
}

/// Ordinary least-squares slope for the sequence of bucket commit counts.
/// Returns 0.0 when the series has fewer than 2 points.
double _linearRegressionSlope(List<int> values) {
  final sampleCount = values.length;
  if (sampleCount < 2) return 0.0;
  double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
  for (int i = 0; i < sampleCount; i++) {
    sumX += i;
    sumY += values[i];
    sumXY += i * values[i];
    sumX2 += i.toDouble() * i;
  }
  final denom = sampleCount * sumX2 - sumX * sumX;
  if (denom == 0) return 0.0;
  return (sampleCount * sumXY - sumX * sumY) / denom;
}
