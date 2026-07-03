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

  test('aggregates one hint per distinct finding source', () {
    final payload = ReportPayload.fromFindings(
      reportType: 'technical',
      findings: [
        findingFrom('analyze_bus_factor'),
        findingFrom('analyze_bug_hotspots', subject: 'lib/y.dart'),
      ],
      compounds: const [],
    );

    expect(payload.hints, isNotEmpty);
    expect(payload.hints.length, lessThanOrEqualTo(6));
    // Both sources have caveats, which take priority over pair_with/
    // interpretation.
    expect(
      payload.hints.any((h) => h.contains('analyze_file_ownership')),
      isTrue,
    );
    expect(payload.hints.any((h) => h.contains('SZZ')), isTrue);
  });

  test('deduplicates and caps at six hints', () {
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

    expect(payload.hints.length, lessThanOrEqualTo(6));
    expect(payload.hints.toSet().length, payload.hints.length);
  });

  test('omits hints when no source has a catalog entry', () {
    final payload = ReportPayload.fromFindings(
      reportType: 'technical',
      findings: [findingFrom('clone_repository')],
      compounds: const [],
    );

    expect(payload.hints, isEmpty);
  });

  test('toJson omits the hints key when empty, includes it after guidance', () {
    final withHints = ReportPayload.fromFindings(
      reportType: 'technical',
      findings: [findingFrom('analyze_bug_hotspots')],
      compounds: const [],
    ).toJson();
    final keys = withHints.keys.toList();

    expect(withHints.containsKey('hints'), isTrue);
    expect(keys.indexOf('hints'), greaterThan(keys.indexOf('guidance')));

    final withoutHints = ReportPayload.fromFindings(
      reportType: 'technical',
      findings: [findingFrom('clone_repository')],
      compounds: const [],
    ).toJson();
    expect(withoutHints.containsKey('hints'), isFalse);
  });
}
