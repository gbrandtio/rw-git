/// ----------------------------------------------------------------------------
/// report_payload.dart
/// ----------------------------------------------------------------------------
/// The bounded, pre-interpreted report a small model narrates directly. Every
/// entry already carries a severity band, a subject, and a message, ranked
/// most-severe first with compound findings surfaced separately — so the model
/// does no band classification, cross-tool joining, or ranking itself.
library;

import 'finding.dart';
import '../orchestration/refactoring_target_ranker.dart';
import 'report_hints.dart';
import '../catalogs/analysis_hints_catalog.dart';
import 'package:rw_git/src/intelligence/interpretation/models/tool_hints.dart';

/// A ranked, size-bounded report payload.
class ReportPayload {
  final String reportType;
  final List<Finding> topFindings;
  final List<Finding> compoundFindings;
  final Map<String, int> summaryBySeverity;
  final Map<String, dynamic> metadata;

  /// Tornhill hotspot prioritization: files ranked by churn percentile x
  /// complexity percentile (Tornhill 2015; Ostrand, Weyuker & Bell 2004),
  /// the ordered "refactor these first" answer. Empty for reports without
  /// both churn and complexity signals (pm, security).
  final List<RefactoringTarget> refactoringTargets;

  /// Research-grounded guidance aggregated from the [analysisHintsCatalog]
  /// entries of the tools that produced [topFindings]/[compoundFindings].
  /// Complements per-finding `basis`/`rationale`: a hint here applies to the
  /// whole analysis (e.g. a caveat about SZZ false-positive rates), not to
  /// one specific observed value. Every distinct interpretation/caveat/
  /// pair_with string contributed by a contributing tool's catalog entry is
  /// included — a caveat never shadows that same tool's pair_with entry.
  final ReportHints hints;

  const ReportPayload({
    required this.reportType,
    required this.topFindings,
    required this.compoundFindings,
    required this.summaryBySeverity,
    required this.metadata,
    this.refactoringTargets = const [],
    this.hints = const ReportHints(),
  });

  /// Ranks and bounds [findings] and correlated [compounds] into a payload
  /// small enough to return inline. Compounds get their own list so they are
  /// never duplicated inside `top_findings` (which holds only singletons).
  factory ReportPayload.fromFindings({
    required String reportType,
    required List<Finding> findings,
    required List<Finding> compounds,
    Map<String, dynamic> metadata = const {},
    List<RefactoringTarget> refactoringTargets = const [],
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
      refactoringTargets: refactoringTargets,
      hints:
          _aggregateHints([...boundedCompoundFindings, ...boundedTopFindings]),
    );
  }

  /// Aggregates every distinct finding `source` (the tool that produced it)
  /// with a [analysisHintsCatalog] entry into a [ReportHints], collecting *all*
  /// three categories per tool rather than picking one — so a caveat can
  /// never crowd out that same tool's pair_with suggestion. Compound
  /// findings carry multiple sources in their list; those are already structured
  /// so each contributor's catalog entry resolves.
  /// Sources are iterated in a fixed,
  /// alphabetically sorted order so the resulting lists are deterministic
  /// regardless of `Set` iteration order. Deliberately uncapped: a report
  /// composes many analyses, and each one's guidance is worth surfacing in
  /// full rather than truncated.
  static ReportHints _aggregateHints(List<Finding> findings) {
    final sortedSources = findings.expand((f) => f.source).toSet().toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final bySource = <String, ToolHints>{};

    for (final source in sortedSources) {
      final catalogHints = analysisHintsCatalog[source];
      if (catalogHints != null) {
        bySource[source.name] = catalogHints;
      }
    }

    return ReportHints(bySource: bySource);
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
        if (refactoringTargets.isNotEmpty)
          'refactoring_targets': {
            'basis': RefactoringTargetRanker.researchBasis,
            'targets':
                refactoringTargets.map((target) => target.toJson()).toList(),
          },
        'metadata': metadata,
        'guidance':
            'Findings are already classified into severity bands and ranked. '
                'Narrate each using its severity, subject, band, and message. '
                'Use the hints map to surface contextually relevant '
                'expert interpretation, caveats, and pair_with guidance '
                'for each analysis type.',
        if (!hints.isEmpty) 'hints': hints.toJson(),
      };
}
