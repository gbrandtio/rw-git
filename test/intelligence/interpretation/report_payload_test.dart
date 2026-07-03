import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

/// [ReportPayload] aggregates report-level `hints` from the
/// [toolHintsCatalog] entries of the tools that produced its findings — see
/// `tool_hints_catalog_test.dart` for the per-tool catalog contract this
/// builds on.
void main() {
  Finding findingFrom(String source, {String subject = 'lib/x.dart'}) =>
      Finding(
        category: 'test',
        source: source,
        severity: Severity.critical,
        subject: subject,
        metric: 'm',
        value: 1,
        band: 'b',
        message: 'msg',
      );

  test(
      'a pair_with entry survives even when the same source also has a '
      'caveat', () {
    // analyze_bus_factor has both a non-empty caveats and pairWith entry in
    // the catalog — the bug this aggregation fixes is a caveat silently
    // shadowing that same tool's pair_with suggestion.
    final catalogEntry = toolHintsCatalog['analyze_bus_factor']!;
    expect(catalogEntry.caveats, isNotEmpty);
    expect(catalogEntry.pairWith, isNotEmpty);

    final payload = ReportPayload.fromFindings(
      reportType: 'technical',
      findings: [findingFrom('analyze_bus_factor')],
      compounds: const [],
    );

    expect(payload.hints.caveats, equals(catalogEntry.caveats.toSet()));
    expect(payload.hints.pairWith, equals(catalogEntry.pairWith.toSet()));
  });

  test('aggregates every category across multiple distinct sources', () {
    final payload = ReportPayload.fromFindings(
      reportType: 'technical',
      findings: [
        findingFrom('analyze_bus_factor'),
        findingFrom('analyze_bug_hotspots', subject: 'lib/y.dart'),
      ],
      compounds: const [],
    );

    final busFactor = toolHintsCatalog['analyze_bus_factor']!;
    final bugHotspots = toolHintsCatalog['analyze_bug_hotspots']!;

    for (final s in [
      ...busFactor.interpretation,
      ...bugHotspots.interpretation
    ]) {
      expect(payload.hints.interpretation, contains(s));
    }
    for (final s in [...busFactor.caveats, ...bugHotspots.caveats]) {
      expect(payload.hints.caveats, contains(s));
    }
    for (final s in [...busFactor.pairWith, ...bugHotspots.pairWith]) {
      expect(payload.hints.pairWith, contains(s));
    }
  });

  test(
      'is not capped: every distinct catalog string across many sources '
      'survives', () {
    final manySources = [
      'analyze_bus_factor',
      'analyze_bug_hotspots',
      'analyze_code_volatility',
      'analyze_commit_velocity',
      'analyze_pr_diff',
      'analyze_release_delta',
      'find_bugs_by_developer',
      'generate_changelog',
    ];
    final payload = ReportPayload.fromFindings(
      reportType: 'audit',
      findings: manySources.map((s) => findingFrom(s)).toList(),
      compounds: const [],
    );

    final expectedInterpretation = <String>{};
    final expectedCaveats = <String>{};
    final expectedPairWith = <String>{};
    for (final source in manySources) {
      final hints = toolHintsCatalog[source]!;
      expectedInterpretation.addAll(hints.interpretation);
      expectedCaveats.addAll(hints.caveats);
      expectedPairWith.addAll(hints.pairWith);
    }

    expect(payload.hints.interpretation.toSet(), expectedInterpretation);
    expect(payload.hints.caveats.toSet(), expectedCaveats);
    expect(payload.hints.pairWith.toSet(), expectedPairWith);
  });

  test('deduplicates each category independently', () {
    final payload = ReportPayload.fromFindings(
      reportType: 'technical',
      findings: [
        findingFrom('analyze_bus_factor', subject: 'lib/a.dart'),
        findingFrom('analyze_bus_factor', subject: 'lib/b.dart'),
      ],
      compounds: const [],
    );

    expect(
      payload.hints.interpretation.length,
      payload.hints.interpretation.toSet().length,
    );
    expect(payload.hints.caveats.length, payload.hints.caveats.toSet().length);
    expect(
      payload.hints.pairWith.length,
      payload.hints.pairWith.toSet().length,
    );
  });

  test('omits hints when no source has a catalog entry', () {
    final payload = ReportPayload.fromFindings(
      reportType: 'technical',
      findings: [findingFrom('clone_repository')],
      compounds: const [],
    );

    expect(payload.hints.isEmpty, isTrue);
  });

  test('toJson emits a hints object with only non-empty category keys', () {
    final withHints = ReportPayload.fromFindings(
      reportType: 'technical',
      findings: [findingFrom('analyze_bug_hotspots')],
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
      findings: [findingFrom('clone_repository')],
      compounds: const [],
    ).toJson();
    expect(withoutHints.containsKey('hints'), isFalse);
  });
}
