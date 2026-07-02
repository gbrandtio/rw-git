import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

/// Refactoring awareness in the technical report (the RA-SZZ insight,
/// Neto et al. 2018): churn explained by structural clean-up must not read
/// as defect risk, and notable refactoring activity is itself a signal
/// worth crediting.
void main() {
  const fc = FindingClassifier();

  RefactoringDto refactoring(List<String> renamed,
          {bool simplification = false, String hash = 'abc123'}) =>
      RefactoringDto(
        commitHash: hash,
        date: '2026-01-01',
        author: 'A',
        message: 'refactor: restructure',
        renamedFiles: renamed,
        linesInserted: 10,
        linesDeleted: simplification ? 100 : 10,
        isSimplification: simplification,
      );

  Finding churnFinding(String subject, Severity severity) => Finding(
        category: 'churn',
        source: 'analyze_code_quality',
        severity: severity,
        subject: subject,
        metric: 'file_churn',
        value: 12,
        band: 'top-decile change frequency',
        message: 'm',
      );

  test('downgrades churn findings on refactored files one band', () {
    final annotated = fc.applyRefactoringContext(
      [churnFinding('lib/moved.dart', Severity.elevated)],
      [
        refactoring(['lib/moved.dart'])
      ],
    );

    final finding = annotated.single;
    expect(finding.severity, Severity.low);
    expect(finding.band, contains('partly explained by refactoring'));
    expect(finding.evidence['refactoring_commits'], contains('abc123'));
  });

  test('leaves non-churn findings and unrefactored files untouched', () {
    final secret = const Finding(
      category: 'secret',
      source: 'detect_secrets_in_commits',
      severity: Severity.critical,
      subject: 'lib/moved.dart',
      metric: 'exposed_secret',
      value: 'redacted',
      band: 'credential exposed in history',
      message: 'm',
    );
    final annotated = fc.applyRefactoringContext(
      [secret, churnFinding('lib/other.dart', Severity.elevated)],
      [
        refactoring(['lib/moved.dart'])
      ],
    );

    // A secret on a refactored file must never be softened.
    expect(annotated[0].severity, Severity.critical);
    expect(annotated[1].severity, Severity.elevated);
  });

  test('no refactorings means findings pass through unchanged', () {
    final original = [churnFinding('lib/x.dart', Severity.elevated)];
    expect(fc.applyRefactoringContext(original, const []), same(original));
  });

  test(
      'notable refactoring activity (>= 5 commits) surfaces as an Elevated '
      'repo-level signal with basis', () {
    final refactorings =
        List.generate(5, (i) => refactoring(['lib/f$i.dart'], hash: 'hash$i'));
    final findings = fc.fromRefactoringActivity(refactorings);

    final finding = findings.single;
    expect(finding.category, 'refactoring');
    expect(finding.severity, Severity.elevated);
    expect(finding.value, 5);
    expect(finding.basis, contains('Neto'));
  });

  test('sparse refactoring activity stays silent', () {
    expect(
        fc.fromRefactoringActivity([
          refactoring(['lib/a.dart'])
        ]),
        isEmpty);
  });
}
