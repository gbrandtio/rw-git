/// ----------------------------------------------------------------------------
/// report_hints.dart
/// ----------------------------------------------------------------------------
/// The aggregated form of [ToolHints] a report payload carries: every distinct
/// interpretation/caveat/pair_with string contributed by the catalog entries
/// of the tools behind a report's findings, grouped by category rather than
/// picked one-per-tool. Mirrors [ToolHints]'s shape and `toJson()` convention
/// so raw-tool hints and report hints read identically to a calling model.
library;

import 'tool_hints.dart';

/// Research-grounded guidance aggregated across every tool that fed a
/// report's findings, grouped into the same three categories as [ToolHints].
class ReportHints {
  final Map<String, ToolHints> bySource;

  const ReportHints({this.bySource = const {}});

  bool get isEmpty => bySource.isEmpty;

  Map<String, dynamic> toJson() =>
      bySource.map((key, value) => MapEntry(key, value.toJson()));
}
