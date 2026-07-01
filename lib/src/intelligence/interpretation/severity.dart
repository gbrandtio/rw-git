/// ----------------------------------------------------------------------------
/// severity.dart
/// ----------------------------------------------------------------------------
/// Severity bands applied deterministically in Dart so the LLM never has to
/// turn a raw metric into a verdict. Ranked so findings can be ordered and
/// escalated without any model reasoning.
library;

/// A severity band. [rank] increases with severity; [label] is the
/// human-facing name used in reports.
enum Severity {
  healthy(0, 'Healthy'),
  normal(1, 'Normal'),
  info(2, 'Info'),
  low(3, 'Low'),
  elevated(4, 'Elevated'),
  moderate(5, 'Moderate'),
  high(6, 'High'),
  critical(7, 'Critical');

  const Severity(this.rank, this.label);

  /// Ordinal weight; higher means more severe.
  final int rank;

  /// Human-facing name emitted in report payloads.
  final String label;

  /// Whether this band is worth surfacing as a report finding. Non-material
  /// bands (healthy/normal/info) are computed for correlation but filtered
  /// out of the ranked `top_findings` a small model narrates.
  bool get isMaterial => rank >= elevated.rank;

  /// Returns the more severe of [a] and [b].
  static Severity max(Severity a, Severity b) => a.rank >= b.rank ? a : b;
}
