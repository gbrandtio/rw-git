/// ----------------------------------------------------------------------------
/// tool_hints.dart
/// ----------------------------------------------------------------------------
/// Research-grounded guidance a tool attaches to its own output, independent
/// of any specific result. Complements [Finding.basis]/[Finding.rationale],
/// which classify a single observed value; a [ToolHints] entry instead tells
/// the caller how to read the tool's output class in general: what
/// thresholds the literature uses, what the analysis can't see, and which
/// other tool to run next.
library;

/// Static, per-tool research guidance surfaced alongside a tool's payload.
class ToolHints {
  /// Threshold bands and interpretation guidance, citation-tagged. Prevents
  /// the caller from inventing thresholds the literature already supplies.
  final List<String> interpretation;

  /// Known limitations of the analysis (false-positive rates, blind spots).
  /// Matter most when a result looks clean, since that is exactly when
  /// overconfidence is costliest.
  final List<String> caveats;

  /// Complementary tools this analysis is designed to be read alongside.
  final List<String> pairWith;

  const ToolHints({
    this.interpretation = const [],
    this.caveats = const [],
    this.pairWith = const [],
  });

  Map<String, dynamic> toJson() => {
        if (interpretation.isNotEmpty) 'interpretation': interpretation,
        if (caveats.isNotEmpty) 'caveats': caveats,
        if (pairWith.isNotEmpty) 'pair_with': pairWith,
      };
}
