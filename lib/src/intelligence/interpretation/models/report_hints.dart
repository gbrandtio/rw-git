/// ----------------------------------------------------------------------------
/// report_hints.dart
/// ----------------------------------------------------------------------------
/// The aggregated form of [ToolHints] a report payload carries: every distinct
/// interpretation/caveat/pair_with string contributed by the catalog entries
/// of the tools behind a report's findings, grouped by category rather than
/// picked one-per-tool. Mirrors [ToolHints]'s shape and `toJson()` convention
/// so raw-tool hints and report hints read identically to a calling model.
library;

/// Research-grounded guidance aggregated across every tool that fed a
/// report's findings, grouped into the same three categories as [ToolHints].
class ReportHints {
  final List<String> interpretation;
  final List<String> caveats;
  final List<String> pairWith;

  const ReportHints({
    this.interpretation = const [],
    this.caveats = const [],
    this.pairWith = const [],
  });

  bool get isEmpty =>
      interpretation.isEmpty && caveats.isEmpty && pairWith.isEmpty;

  Map<String, dynamic> toJson() => {
        if (interpretation.isNotEmpty) 'interpretation': interpretation,
        if (caveats.isNotEmpty) 'caveats': caveats,
        if (pairWith.isNotEmpty) 'pair_with': pairWith,
      };
}
