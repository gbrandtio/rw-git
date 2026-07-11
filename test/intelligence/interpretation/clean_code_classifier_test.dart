import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

/// The clean-code classifier carries the Martin/Fowler/Koschke heuristics
/// into the technical, code-review, and audit reports; these tests pin the
/// severity mapping (any issue Elevated, 3+ issues High) so a change is a
/// deliberate ADR-0010 act.
void main() {
  const fc = FindingClassifier();

  CleanCodeMetricsDto metrics(String path, List<String> issues) =>
      CleanCodeMetricsDto(
        filePath: path,
        totalLines: 100,
        maxIndentationLevel: 2,
        longLines: 0,
        magicNumbers: 0,
        duplicateLines: 0,
        issues: issues,
      );

  test('files without issues produce no finding', () {
    expect(fc.fromCleanCode([metrics('lib/clean.dart', const [])]), isEmpty);
  });

  test('one crossed heuristic bands Elevated', () {
    final finding = fc.fromCleanCode([
      metrics('lib/one.dart', const ['too long']),
    ]).single;

    expect(finding.severity, Severity.elevated);
    expect(finding.category, 'cleanCode');
    expect(finding.source, [AnalysisType.cleanCode]);
    expect(finding.value, 1);
  });

  test('three or more agreeing heuristics escalate to High', () {
    final finding = fc.fromCleanCode([
      metrics('lib/bad.dart', const [
        'too long',
        'nesting',
        'magic numbers',
      ]),
    ]).single;

    expect(finding.severity, Severity.high);
    expect(finding.band, contains('3'));
  });

  test('evidence carries the full measured metrics', () {
    final finding = fc.fromCleanCode([
      metrics('lib/one.dart', const ['issue']),
    ]).single;

    expect(finding.evidence.keys, [
      'total_lines',
      'max_indentation_level',
      'long_lines',
      'magic_numbers',
      'duplicate_lines',
    ]);
  });
}
