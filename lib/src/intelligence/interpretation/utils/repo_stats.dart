/// ----------------------------------------------------------------------------
/// repo_stats.dart
/// ----------------------------------------------------------------------------
/// Pure statistical helpers backing the repo-relative severity bands (compare
/// a file against the repository's own distribution rather than an invented
/// absolute cut-off). All helpers copy their input and never mutate it.
library;

/// Distribution helpers over a set of metric values.
class RepoStats {
  const RepoStats._();

  /// Linear-interpolated percentile [p] in `[0, 1]`. Returns `0.0` for an
  /// empty input so callers can treat "no data" as "no signal".
  static double percentile(Iterable<num> values, double p) {
    final sorted = values.map((v) => v.toDouble()).toList()..sort();
    if (sorted.isEmpty) return 0.0;
    if (sorted.length == 1) return sorted.first;
    final clamped =
        p < 0
            ? 0.0
            : p > 1
            ? 1.0
            : p;
    final rank = clamped * (sorted.length - 1);
    final lower = rank.floor();
    final upper = rank.ceil();
    if (lower == upper) return sorted[lower];
    final weight = rank - lower;
    return sorted[lower] * (1 - weight) + sorted[upper] * weight;
  }

  /// The median (50th percentile).
  static double median(Iterable<num> values) => percentile(values, 0.5);

  /// The first and third quartiles `(q1, q3)`.
  static (double, double) quartiles(Iterable<num> values) => (
    percentile(values, 0.25),
    percentile(values, 0.75),
  );

  /// The inter-quartile range `q3 - q1`.
  static double iqr(Iterable<num> values) {
    final (q1, q3) = quartiles(values);
    return q3 - q1;
  }

  /// The threshold at/above which a value sits in the top decile (90th
  /// percentile).
  static double topDecileThreshold(Iterable<num> values) =>
      percentile(values, 0.9);
}
