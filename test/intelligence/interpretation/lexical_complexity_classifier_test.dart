import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

/// The lexical complexity classifier is what finally carries the genuine
/// lexical suite — McCabe cyclomatic complexity, maintainability index,
/// ABC score, NPath, cognitive complexity, and the Halstead delivered-bugs
/// estimate — into the report meta-tools; these tests pin the standard
/// absolute bands (McCabe 1976; Coleman et al. 1994; Fitzpatrick 1997;
/// Nejmeh 1988; Campbell 2018; Halstead 1977) so a threshold change is a
/// deliberate ADR-0010 act.
void main() {
  const fc = FindingClassifier();

  FileLexicalMetricsDto metrics(
    String path,
    int cc,
    double mi, {
    double abc = 0,
    int npath = 1,
    int cognitive = 0,
    double deliveredBugs = 0,
  }) => FileLexicalMetricsDto(
    filePath: path,
    cyclomaticComplexity: cc,
    maintainabilityIndex: mi,
    abcScore: abc,
    npathComplexity: npath,
    cognitiveComplexity: cognitive,
    halsteadDeliveredBugs: deliveredBugs,
  );

  test('McCabe bands: >50 critical, 21-50 high, 11-20 elevated, <=10 skip', () {
    final findings = fc.fromLexicalMetrics([
      metrics('lib/untestable.dart', 51, 95),
      metrics('lib/high.dart', 21, 95),
      metrics('lib/moderate.dart', 11, 95),
      metrics('lib/simple.dart', 10, 95),
    ]);
    final bySubject = {for (final f in findings) f.subject: f};

    expect(bySubject['lib/untestable.dart']!.severity, Severity.critical);
    expect(bySubject['lib/high.dart']!.severity, Severity.high);
    expect(bySubject['lib/moderate.dart']!.severity, Severity.elevated);
    expect(bySubject.containsKey('lib/simple.dart'), isFalse);
    expect(bySubject['lib/high.dart']!.metric, 'cyclomatic_complexity');
    expect(bySubject['lib/high.dart']!.category, 'lexicalComplexity');
  });

  test('maintainability bands: <65 high, 65-85 elevated, >=85 skip', () {
    final findings = fc.fromLexicalMetrics([
      metrics('lib/low_mi.dart', 5, 60),
      metrics('lib/moderate_mi.dart', 5, 70),
      metrics('lib/healthy.dart', 5, 90),
    ]);
    final bySubject = {for (final f in findings) f.subject: f};

    expect(bySubject['lib/low_mi.dart']!.severity, Severity.high);
    expect(bySubject['lib/low_mi.dart']!.metric, 'maintainability_index');
    expect(bySubject['lib/moderate_mi.dart']!.severity, Severity.elevated);
    expect(bySubject.containsKey('lib/healthy.dart'), isFalse);
  });

  test('ABC bands: >30 high, >15 elevated, <=15 skip (Fitzpatrick 1997)', () {
    final findings = fc.fromLexicalMetrics([
      metrics('lib/abc_high.dart', 5, 95, abc: 30.1),
      metrics('lib/abc_elevated.dart', 5, 95, abc: 15.1),
      metrics('lib/abc_ok.dart', 5, 95, abc: 15),
    ]);
    final bySubject = {for (final f in findings) f.subject: f};

    expect(bySubject['lib/abc_high.dart']!.severity, Severity.high);
    expect(bySubject['lib/abc_high.dart']!.metric, 'abc_score');
    expect(bySubject['lib/abc_elevated.dart']!.severity, Severity.elevated);
    expect(bySubject.containsKey('lib/abc_ok.dart'), isFalse);
  });

  test('NPath bands: >1000 high, >200 elevated, <=200 skip (Nejmeh 1988)', () {
    final findings = fc.fromLexicalMetrics([
      metrics('lib/npath_high.dart', 5, 95, npath: 1001),
      metrics('lib/npath_elevated.dart', 5, 95, npath: 201),
      metrics('lib/npath_ok.dart', 5, 95, npath: 200),
    ]);
    final bySubject = {for (final f in findings) f.subject: f};

    expect(bySubject['lib/npath_high.dart']!.severity, Severity.high);
    expect(bySubject['lib/npath_high.dart']!.metric, 'npath_complexity');
    expect(bySubject['lib/npath_elevated.dart']!.severity, Severity.elevated);
    expect(bySubject.containsKey('lib/npath_ok.dart'), isFalse);
  });

  test(
    'cognitive bands: >25 high, >15 elevated, <=15 skip (Campbell 2018)',
    () {
      final findings = fc.fromLexicalMetrics([
        metrics('lib/cog_high.dart', 5, 95, cognitive: 26),
        metrics('lib/cog_elevated.dart', 5, 95, cognitive: 16),
        metrics('lib/cog_ok.dart', 5, 95, cognitive: 15),
      ]);
      final bySubject = {for (final f in findings) f.subject: f};

      expect(bySubject['lib/cog_high.dart']!.severity, Severity.high);
      expect(bySubject['lib/cog_high.dart']!.metric, 'cognitive_complexity');
      expect(bySubject['lib/cog_elevated.dart']!.severity, Severity.elevated);
      expect(bySubject.containsKey('lib/cog_ok.dart'), isFalse);
    },
  );

  test('Halstead delivered-bugs band: >2.0 elevated, <=2.0 skip '
      '(Halstead 1977)', () {
    final findings = fc.fromLexicalMetrics([
      metrics('lib/buggy_estimate.dart', 5, 95, deliveredBugs: 2.1),
      metrics('lib/clean_estimate.dart', 5, 95, deliveredBugs: 2.0),
    ]);
    final bySubject = {for (final f in findings) f.subject: f};

    expect(bySubject['lib/buggy_estimate.dart']!.severity, Severity.elevated);
    expect(
      bySubject['lib/buggy_estimate.dart']!.metric,
      'halstead_delivered_bugs',
    );
    expect(bySubject.containsKey('lib/clean_estimate.dart'), isFalse);
  });

  test('one finding per file: the worst metric wins, all ride in evidence', () {
    final findings = fc.fromLexicalMetrics([
      metrics(
        'lib/both.dart',
        25,
        60,
        abc: 16,
        npath: 300,
        cognitive: 20,
        deliveredBugs: 2.5,
      ),
    ]);

    final finding = findings.single;
    // CC 25 is High; MI 60 is also High — CC dominates on ties because it
    // is banded first in the suite.
    expect(finding.metric, 'cyclomatic_complexity');
    expect(finding.evidence['cyclomatic_complexity'], 25);
    expect(finding.evidence['maintainability_index'], 60);
    expect(finding.evidence['abc_score'], 16);
    expect(finding.evidence['npath_complexity'], 300);
    expect(finding.evidence['cognitive_complexity'], 20);
    expect(finding.evidence['halstead_delivered_bugs'], 2.5);
  });
}
