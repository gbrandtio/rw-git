import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

/// Compound Rule 5: the cross-tool join introduced with report-grade lexical
/// metrics — the strongest defect predictor the report computes (genuine
/// McCabe outlier that also churns).
void main() {
  const fc = FindingClassifier();
  const correlator = CompoundFindingCorrelator();

  List<Finding> lexicalHigh(String subject) => fc.fromLexicalMetrics([
        FileLexicalMetricsDto(
          filePath: subject,
          cyclomaticComplexity: 30,
          maintainabilityIndex: 90,
          abcScore: 0,
          npathComplexity: 1,
          cognitiveComplexity: 0,
          halsteadDeliveredBugs: 0,
        ),
      ]);

  List<Finding> churnOn(String subject) => fc.fromChurn(
        ChurnMetricsDto(
          fileChurn: {subject: 10, 'a': 1, 'b': 1, 'c': 1},
          totalCommits: 13,
        ),
      );

  test(
    'Rule 5: high McCabe complexity + churn on the same file is Critical',
    () {
      final compounds = correlator.correlate([
        ...lexicalHigh('lib/x.dart'),
        ...churnOn('lib/x.dart'),
      ]);

      final compound = compounds.singleWhere(
        (c) => c.metric == 'real_complexity_x_churn',
      );
      expect(compound.severity, Severity.critical);
      expect(compound.subject, 'lib/x.dart');
      expect(compound.source, contains(AnalysisType.universalLexicalMetrics));
    },
  );

  test('Rule 5 requires the same subject and at least High severity', () {
    // Different files: no compound.
    expect(
      correlator.correlate([
        ...lexicalHigh('lib/x.dart'),
        ...churnOn('lib/y.dart')
      ]).where((c) => c.metric == 'real_complexity_x_churn'),
      isEmpty,
    );

    // Elevated-only lexical finding (CC 15): no compound.
    final elevatedOnly = fc.fromLexicalMetrics([
      const FileLexicalMetricsDto(
        filePath: 'lib/x.dart',
        cyclomaticComplexity: 15,
        maintainabilityIndex: 90,
        abcScore: 0,
        npathComplexity: 1,
        cognitiveComplexity: 0,
        halsteadDeliveredBugs: 0,
      ),
    ]);
    expect(
      correlator.correlate([...elevatedOnly, ...churnOn('lib/x.dart')]).where(
          (c) => c.metric == 'real_complexity_x_churn'),
      isEmpty,
    );
  });
}
