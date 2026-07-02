import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

/// Compound Rules 5 and 6: the cross-tool joins introduced with the
/// report-grade lexical metrics and conflict prediction. Rule 5 is the
/// strongest defect predictor the report computes (genuine McCabe outlier
/// that also churns); Rule 6 flags merges into bug-breeding code.
void main() {
  const fc = FindingClassifier();
  const correlator = CompoundFindingCorrelator();

  List<Finding> lexicalHigh(String subject) => fc.fromLexicalMetrics([
        FileLexicalMetricsDto(
            filePath: subject,
            cyclomaticComplexity: 30,
            maintainabilityIndex: 90),
      ]);

  List<Finding> churnOn(String subject) => fc.fromChurn(ChurnMetricsDto(
        fileChurn: {subject: 10, 'a': 1, 'b': 1, 'c': 1},
        classChurn: const {},
        blockChurn: const {},
        totalCommits: 13,
      ));

  test('Rule 5: high McCabe complexity + churn on the same file is Critical',
      () {
    final compounds = correlator
        .correlate([...lexicalHigh('lib/x.dart'), ...churnOn('lib/x.dart')]);

    final compound =
        compounds.singleWhere((c) => c.metric == 'real_complexity_x_churn');
    expect(compound.severity, Severity.critical);
    expect(compound.subject, 'lib/x.dart');
    expect(compound.source, contains('calculate_universal_lexical_metrics'));
    expect(compound.basis, contains('McCabe'));
    expect(compound.rationale, contains('1976'));
  });

  test('Rule 5 requires the same subject and at least High severity', () {
    // Different files: no compound.
    expect(
        correlator.correlate([
          ...lexicalHigh('lib/x.dart'),
          ...churnOn('lib/y.dart')
        ]).where((c) => c.metric == 'real_complexity_x_churn'),
        isEmpty);

    // Elevated-only lexical finding (CC 15): no compound.
    final elevatedOnly = fc.fromLexicalMetrics([
      const FileLexicalMetricsDto(
          filePath: 'lib/x.dart',
          cyclomaticComplexity: 15,
          maintainabilityIndex: 90),
    ]);
    expect(
        correlator.correlate([...elevatedOnly, ...churnOn('lib/x.dart')]).where(
            (c) => c.metric == 'real_complexity_x_churn'),
        isEmpty);
  });

  test('Rule 6: predicted conflict on a bug hotspot is a High compound', () {
    final conflict = fc.fromConflictRisk({
      'textual_conflicting_files': ['lib/hot.dart'],
      'conflicting_files': [],
    });
    final hotspot = fc.fromBugHotspots(BugHotspotDto(
      fileHotspots: {'lib/hot.dart': 5},
      authorHotspots: const {},
      totalFixCommitsAnalyzed: 5,
      globalAverageBugLifetimeInDays: 10,
      fileAverageBugLifetimeInDays: {'lib/hot.dart': 100},
      authorAverageBugLifetimeInDays: const {},
    ));

    final compounds = correlator.correlate([...conflict, ...hotspot]);
    final compound =
        compounds.singleWhere((c) => c.metric == 'conflict_x_bug_hotspot');
    expect(compound.severity, Severity.high);
    expect(compound.subject, 'lib/hot.dart');
    expect(compound.basis, contains('Brun'));
  });
}
