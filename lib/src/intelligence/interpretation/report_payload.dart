/// ----------------------------------------------------------------------------
/// report_payload.dart
/// ----------------------------------------------------------------------------
/// The bounded, pre-interpreted report a small model narrates directly. Every
/// entry already carries a severity band, a subject, and a message, ranked
/// most-severe first with compound findings surfaced separately — so the model
/// does no band classification, cross-tool joining, or ranking itself.
library;

import 'finding.dart';
import 'tool_hints_catalog.dart';

/// Upper bound on how many tool-level hints a report aggregates. Reports
/// compose many analyses, so this keeps the composed set bounded regardless
/// of how many distinct tools contributed findings.
const int _maxReportHints = 6;

/// A ranked, size-bounded report payload.
class ReportPayload {
  final String reportType;
  final List<Finding> topFindings;
  final List<Finding> compoundFindings;
  final Map<String, int> summaryBySeverity;
  final Map<String, dynamic> metadata;

  /// Research-grounded guidance aggregated from the [toolHintsCatalog]
  /// entries of the tools that produced [topFindings]/[compoundFindings].
  /// Complements per-finding `basis`/`rationale`: a hint here applies to the
  /// whole analysis (e.g. a caveat about SZZ false-positive rates), not to
  /// one specific observed value.
  final List<String> hints;

  const ReportPayload({
    required this.reportType,
    required this.topFindings,
    required this.compoundFindings,
    required this.summaryBySeverity,
    required this.metadata,
    this.hints = const [],
  });

  /// Ranks and bounds [findings] and correlated [compounds] into a payload
  /// small enough to return inline. Compounds get their own list so they are
  /// never duplicated inside `top_findings` (which holds only singletons).
  factory ReportPayload.fromFindings({
    required String reportType,
    required List<Finding> findings,
    required List<Finding> compounds,
    Map<String, dynamic> metadata = const {},
    int maxTopFindings = 8,
    int maxCompoundFindings = 5,
  }) {
    final summary = <String, int>{};
    for (final f in [...compounds, ...findings]) {
      summary[f.severity.label] = (summary[f.severity.label] ?? 0) + 1;
    }

    final singletons = findings.where((f) => f.severity.isMaterial).toList()
      ..sort(_rank);
    final rankedCompounds = compounds.toList()..sort(_rank);

    final boundedTopFindings = singletons.take(maxTopFindings).toList();
    final boundedCompoundFindings =
        rankedCompounds.take(maxCompoundFindings).toList();

    return ReportPayload(
      reportType: reportType,
      topFindings: boundedTopFindings,
      compoundFindings: boundedCompoundFindings,
      summaryBySeverity: summary,
      metadata: metadata,
      hints: _selectHints([...boundedCompoundFindings, ...boundedTopFindings]),
    );
  }

  /// Picks one hint per distinct finding `source` (the tool that produced
  /// it), preferring a caveat, then a pair_with suggestion, then an
  /// interpretation threshold — the same priority the offload preview uses
  /// (highest decision value per token first). Deduped and capped at
  /// [_maxReportHints] since a report composes many analyses.
  static List<String> _selectHints(List<Finding> findings) {
    final sources = findings.map((f) => f.source).toSet();
    final selected = <String>[];

    for (final source in sources) {
      final catalogHints = toolHintsCatalog[source];
      if (catalogHints == null) continue;

      final pick = catalogHints.caveats.isNotEmpty
          ? catalogHints.caveats.first
          : catalogHints.pairWith.isNotEmpty
              ? catalogHints.pairWith.first
              : catalogHints.interpretation.isNotEmpty
                  ? catalogHints.interpretation.first
                  : null;
      if (pick != null) selected.add(pick);
    }

    return selected.toSet().take(_maxReportHints).toList();
  }

  /// Ranks by severity (desc), then compound-first, then numeric magnitude.
  static int _rank(Finding a, Finding b) {
    final bySeverity = b.severity.rank.compareTo(a.severity.rank);
    if (bySeverity != 0) return bySeverity;

    final aCompound = a.category == 'compound' ? 1 : 0;
    final bCompound = b.category == 'compound' ? 1 : 0;
    if (aCompound != bCompound) return bCompound - aCompound;

    final coercedValueA = a.value is num ? (a.value as num).toDouble() : 0.0;
    final coercedValueB = b.value is num ? (b.value as num).toDouble() : 0.0;
    return coercedValueB.compareTo(coercedValueA);
  }

  Map<String, dynamic> toJson() => {
        'report_type': reportType,
        'summary': summaryBySeverity,
        'top_findings': topFindings.map((f) => f.toJson()).toList(),
        'compound_findings': compoundFindings.map((f) => f.toJson()).toList(),
        'metadata': metadata,
        'guidance':
            'Findings are already classified into severity bands and ranked. '
                'Narrate each using its severity, subject, band, and message; '
                'no further interpretation, statistics, or cross-referencing '
                'is required.',
        if (hints.isNotEmpty) 'hints': hints,
      };
}
