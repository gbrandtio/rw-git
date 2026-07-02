/// ----------------------------------------------------------------------------
/// finding.dart
/// ----------------------------------------------------------------------------
/// A single interpreted finding: a raw metric already classified into a
/// severity band by deterministic Dart. This is the unit a small model
/// narrates instead of computing bands, joins, and rankings itself.
library;

import 'severity.dart';

/// An interpreted, band-classified observation about the repository.
class Finding {
  /// Coarse family used for grouping and correlation, e.g. `busFactor`,
  /// `bugHotspot`, `complexity`, `churn`, `coupling`, `volatility`,
  /// `dependency`, `compliance`, `secret`, `ownership`, `compound`.
  final String category;

  /// The tool/algorithm that produced the underlying metric.
  final String source;

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

  /// One-line human summary of the finding.
  final String message;

  /// Compact academic citation tag behind the band, e.g.
  /// `Truck-factor estimation (Avelino et al. 2016)`. Carried inline in the
  /// offload preview, so classifiers must keep it short (~90 chars) — every
  /// character is a recurring token cost in each report.
  final String? basis;

  /// One-to-two-sentence research rationale with the citation, explaining
  /// why the metric predicts risk. Present only in the offloaded full
  /// report: the offload decorator strips it from preview copies.
  final String? rationale;

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
    required this.message,
    this.basis,
    this.rationale,
    this.evidence = const {},
  });

  /// Returns a copy with selected fields overridden.
  Finding copyWith({
    Severity? severity,
    String? band,
    String? message,
    String? basis,
    String? rationale,
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
      message: message ?? this.message,
      basis: basis ?? this.basis,
      rationale: rationale ?? this.rationale,
      evidence: evidence ?? this.evidence,
    );
  }

  Map<String, dynamic> toJson() => {
        'category': category,
        'source': source,
        'severity': severity.label,
        'subject': subject,
        'metric': metric,
        'value': value,
        'band': band,
        'message': message,
        if (basis != null) 'basis': basis,
        if (rationale != null) 'rationale': rationale,
        if (evidence.isNotEmpty) 'evidence': evidence,
      };
}
