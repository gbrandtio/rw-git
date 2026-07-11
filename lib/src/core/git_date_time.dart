/// ----------------------------------------------------------------------------
/// git_date_time.dart
/// ----------------------------------------------------------------------------
/// Parses git author/committer timestamps while preserving the UTC offset.
///
/// Dart's [DateTime.parse] converts offset-bearing ISO 8601 strings to UTC,
/// which silently discards the author's timezone. Metrics that depend on the
/// author's wall-clock time (e.g. burnout detection on commit hour) must use
/// [authorLocal]; metrics that compare instants across commits must use [utc].
class GitDateTime {
  /// The exact instant of the timestamp, with `isUtc == true`.
  final DateTime utc;

  /// The author's UTC offset at the time of the commit (e.g. +04:00).
  final Duration offset;

  GitDateTime._(this.utc, this.offset);

  /// The author's wall-clock time. The returned [DateTime] is flagged as UTC
  /// so that no further conversion to the machine-local timezone can occur;
  /// its year/month/day/hour fields are the ones the author saw locally.
  DateTime get authorLocal => utc.add(offset);

  /// Accepts the ISO 8601 variants git emits (`%aI`, `--date=iso`,
  /// `--date=iso-strict`): date and time separated by `T` or a space, an
  /// optional fractional-seconds part, and a mandatory `Z` or `±hh[:]mm`
  /// offset optionally preceded by a space.
  static final RegExp _gitTimestampPattern = RegExp(
    r'^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2}:\d{2}(?:\.\d+)?)\s*(Z|[+-]\d{2}:?\d{2})$',
  );

  /// Throws a [FormatException] when [raw] is not a timezone-qualified git
  /// timestamp. Callers must not substitute a fallback value (such as
  /// `DateTime.now()`) on failure: a wrong timestamp silently corrupts every
  /// downstream metric, so parsing failures have to surface immediately.
  static GitDateTime parse(String raw) {
    final match = _gitTimestampPattern.firstMatch(raw.trim());
    if (match == null) {
      throw FormatException(
        'Not an ISO 8601 git timestamp with a UTC offset',
        raw,
      );
    }

    // Parsing the wall-clock portion with a forced `Z` keeps the author's
    // local field values intact instead of shifting them to machine-local.
    final wallClock = DateTime.parse('${match.group(1)}T${match.group(2)}Z');

    final zone = match.group(3)!;
    Duration offset;
    if (zone == 'Z') {
      offset = Duration.zero;
    } else {
      final digits = zone.substring(1).replaceAll(':', '');
      offset = Duration(
            hours: int.parse(digits.substring(0, 2)),
            minutes: int.parse(digits.substring(2, 4)),
          ) *
          (zone.startsWith('-') ? -1 : 1);
    }

    return GitDateTime._(wallClock.subtract(offset), offset);
  }
}
