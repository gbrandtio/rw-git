import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

/// The lexical complexity classifier is what finally carries genuine McCabe
/// cyclomatic complexity and the maintainability index into the report
/// meta-tools; these tests pin the standard absolute bands (McCabe 1976;
/// Coleman et al. 1994) so a threshold change is a deliberate ADR-0010 act.
void main() {
  const fc = FindingClassifier();

  FileLexicalMetricsDto metrics(String path, int cc, double mi) =>
      FileLexicalMetricsDto(
          filePath: path, cyclomaticComplexity: cc, maintainabilityIndex: mi);

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

  test('one finding per file: the worse metric wins, both ride in evidence',
      () {
    final findings = fc.fromLexicalMetrics([metrics('lib/both.dart', 25, 60)]);

    final finding = findings.single;
    // CC 25 is High; MI 60 is also High — CC dominates on ties.
    expect(finding.metric, 'cyclomatic_complexity');
    expect(finding.evidence['cyclomatic_complexity'], 25);
    expect(finding.evidence['maintainability_index'], 60);
    expect(finding.basis, contains('McCabe'));
    expect(finding.rationale, contains('1976'));
  });
}
