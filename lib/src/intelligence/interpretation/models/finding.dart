/// ----------------------------------------------------------------------------
/// finding.dart
/// ----------------------------------------------------------------------------
/// A single interpreted finding: a raw metric already classified into a
/// severity band by deterministic Dart. This is the unit a small model
/// narrates instead of computing bands, joins, and rankings itself.
library;

import 'severity.dart';
import 'analysis_type.dart';

/// An interpreted, band-classified observation about the repository.
class Finding {
  /// Coarse family used for grouping and correlation, e.g. `busFactor`,
  /// `bugHotspot`, `complexity`, `churn`, `coupling`, `volatility`,
  /// `dependency`, `compliance`, `secret`, `ownership`, `compound`.
  final String category;

  /// The tools/algorithms that produced the underlying metric.
  final List<AnalysisType> source;

  /// The band assigned to the metric.
  final Severity severity;

  /// Normalised join key: a file path, author, or dependency name. Used by
  /// the compound-finding correlator to line findings up across tools.
  final String subject;

  /// The metric name, e.g. `file_average_bug_lifetime_in_days`.
  final String metric;

  /// The raw metric value (number or string) behind the band.
  final Object? value;

  /// Human-readable band description, e.g. `> 2x global average`.
  final String band;

  /// Supporting evidence: thresholds, correlated sources, raw numbers.
  final Map<String, dynamic> evidence;

  const Finding({
    required this.category,
    required this.source,
    required this.severity,
    required this.subject,
    required this.metric,
    required this.value,
    required this.band,
    this.evidence = const {},
  });

  /// Returns a copy with selected fields overridden.
  Finding copyWith({
    Severity? severity,
    String? band,
    Map<String, dynamic>? evidence,
  }) {
    return Finding(
      category: category,
      source: source,
      severity: severity ?? this.severity,
      subject: subject,
      metric: metric,
      value: value,
      band: band ?? this.band,
      evidence: evidence ?? this.evidence,
    );
  }

  Map<String, dynamic> toJson() => {
        'category': category,
        'source': source.map((s) => s.name).toList(),
        'severity': severity.label,
        'subject': subject,
        'metric': metric,
        'value': value,
        'band': band,
        if (evidence.isNotEmpty) 'evidence': evidence,
      };
}
