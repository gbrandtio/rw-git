import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

/// [ReportPayload] aggregates report-level `hints` from the
/// [analysisHintsCatalog] entries of the tools that produced its findings — see
/// `analysis_hints_catalog_test.dart` for the per-tool catalog contract this
/// builds on.
void main() {
  Finding findingFrom(List<AnalysisType> source,
          {String subject = 'lib/x.dart'}) =>
      Finding(
        category: 'test',
        source: source,
        severity: Severity.critical,
        subject: subject,
        metric: 'm',
        value: 1,
        band: 'b',
      );

  test(
      'a pair_with entry survives even when the same source also has a '
      'caveat', () {
    // analyze_bus_factor has both a non-empty caveats and pairWith entry in
    // the catalog — the bug this aggregation fixes is a caveat silently
    // shadowing that same tool's pair_with suggestion.
    final catalogEntry = analysisHintsCatalog[AnalysisType.busFactor]!;
    expect(catalogEntry.caveats, isNotEmpty);
    expect(catalogEntry.pairWith, isNotEmpty);

    final payload = ReportPayload.fromFindings(
      reportType: 'technical',
      findings: [
        findingFrom([AnalysisType.busFactor])
      ],
      compounds: const [],
    );

    expect(payload.hints.bySource[AnalysisType.busFactor.name]!.caveats,
        equals(catalogEntry.caveats));
    expect(payload.hints.bySource[AnalysisType.busFactor.name]!.pairWith,
        equals(catalogEntry.pairWith));
  });

  test('aggregates every category across multiple distinct sources', () {
    final payload = ReportPayload.fromFindings(
      reportType: 'technical',
      findings: [
        findingFrom([AnalysisType.busFactor]),
        findingFrom([AnalysisType.bugHotspots], subject: 'lib/y.dart'),
      ],
      compounds: const [],
    );

    final busFactor = analysisHintsCatalog[AnalysisType.busFactor]!;
    final bugHotspots = analysisHintsCatalog[AnalysisType.bugHotspots]!;

    expect(payload.hints.bySource[AnalysisType.busFactor.name]!.interpretation,
        equals(busFactor.interpretation));
    expect(
        payload.hints.bySource[AnalysisType.bugHotspots.name]!.interpretation,
        equals(bugHotspots.interpretation));

    expect(payload.hints.bySource[AnalysisType.busFactor.name]!.caveats,
        equals(busFactor.caveats));
    expect(payload.hints.bySource[AnalysisType.bugHotspots.name]!.caveats,
        equals(bugHotspots.caveats));

    expect(payload.hints.bySource[AnalysisType.busFactor.name]!.pairWith,
        equals(busFactor.pairWith));
    expect(payload.hints.bySource[AnalysisType.bugHotspots.name]!.pairWith,
        equals(bugHotspots.pairWith));
  });

  test(
      'is not capped: every distinct catalog string across many sources '
      'survives', () {
    final manySources = [
      AnalysisType.busFactor,
      AnalysisType.bugHotspots,
      AnalysisType.codeVolatility,
      AnalysisType.commitVelocity,
      AnalysisType.releaseDelta,
      AnalysisType.changelog,
    ];
    final payload = ReportPayload.fromFindings(
      reportType: 'audit',
      findings: manySources.map((s) => findingFrom([s])).toList(),
      compounds: const [],
    );

    for (final source in manySources) {
      final catalogHints = analysisHintsCatalog[source]!;
      final aggregatedHints = payload.hints.bySource[source.name]!;

      expect(
          aggregatedHints.interpretation, equals(catalogHints.interpretation));
      expect(aggregatedHints.caveats, equals(catalogHints.caveats));
      expect(aggregatedHints.pairWith, equals(catalogHints.pairWith));
    }
  });

  test('deduplicates each category independently', () {
    final payload = ReportPayload.fromFindings(
      reportType: 'technical',
      findings: [
        findingFrom([AnalysisType.busFactor], subject: 'lib/a.dart'),
        findingFrom([AnalysisType.busFactor], subject: 'lib/b.dart'),
      ],
      compounds: const [],
    );

    for (final hints in payload.hints.bySource.values) {
      expect(hints.interpretation.length, hints.interpretation.toSet().length);
      expect(hints.caveats.length, hints.caveats.toSet().length);
      expect(hints.pairWith.length, hints.pairWith.toSet().length);
    }
  });

  test('omits hints when no source has a catalog entry', () {
    final payload = ReportPayload.fromFindings(
      reportType: 'technical',
      findings: [findingFrom([])],
      compounds: const [],
    );

    expect(payload.hints.isEmpty, isTrue);
  });

  test('toJson emits a hints object with only non-empty category keys', () {
    final withHints = ReportPayload.fromFindings(
      reportType: 'technical',
      findings: [
        findingFrom([AnalysisType.bugHotspots])
      ],
      compounds: const [],
    ).toJson();
    final keys = withHints.keys.toList();

    expect(withHints.containsKey('hints'), isTrue);
    expect(keys.indexOf('hints'), greaterThan(keys.indexOf('guidance')));

    final hintsJson = withHints['hints'] as Map<String, dynamic>;
    for (final value in hintsJson.values) {
      expect(value, isNotEmpty);
    }

    final withoutHints = ReportPayload.fromFindings(
      reportType: 'technical',
      findings: [findingFrom([])],
      compounds: const [],
    ).toJson();
    expect(withoutHints.containsKey('hints'), isFalse);
  });

  test(
      'compound findings contribute hints: their joined source string is '
      'split back into catalog keys', () {
    // A compound's source is 'tool_a + tool_b' — before the split fix,
    // that string matched no catalog key and compounds (the highest-
    // priority findings) contributed no hints at all.
    final payload = ReportPayload.fromFindings(
      reportType: 'technical',
      findings: const [],
      compounds: [
        findingFrom([AnalysisType.bugHotspots, AnalysisType.fileOwnership]),
      ],
    );

    final bugHotspots = analysisHintsCatalog[AnalysisType.bugHotspots]!;
    final ownership = analysisHintsCatalog[AnalysisType.fileOwnership]!;
    expect(
        payload.hints.bySource[AnalysisType.bugHotspots.name]!.interpretation,
        equals(bugHotspots.interpretation));
    expect(
        payload.hints.bySource[AnalysisType.fileOwnership.name]!.interpretation,
        equals(ownership.interpretation));
  });

  test('toJson emits refactoring_targets with basis only when non-empty', () {
    const target = RefactoringTarget(
      filePath: 'lib/hot.dart',
      riskScore: 0.9,
      churn: 42,
      churnPercentile: 0.95,
      complexityMetric: 'cyclomatic_complexity',
      complexityValue: 30,
      complexityPercentile: 0.95,
    );
    final withTargets = ReportPayload.fromFindings(
      reportType: 'technical',
      findings: const [],
      compounds: const [],
      refactoringTargets: const [target],
    ).toJson();

    final targetsJson = withTargets['refactoring_targets'] as Map;
    expect(targetsJson['basis'], contains('Tornhill'));
    final targetJson =
        (targetsJson['targets'] as List).single as Map<String, dynamic>;
    expect(targetJson['file_path'], 'lib/hot.dart');

    final withoutTargets = ReportPayload.fromFindings(
      reportType: 'pm',
      findings: const [],
      compounds: const [],
    ).toJson();
    expect(withoutTargets.containsKey('refactoring_targets'), isFalse);
  });
}
