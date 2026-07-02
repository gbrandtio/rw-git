import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

/// Commit-hygiene signals for the repository audit: mega commits and
/// suspicious commits aggregate into one bounded finding per family (the
/// compliance-classifier pattern) so hundreds of hits cannot flood the
/// ranked findings.
void main() {
  const fc = FindingClassifier();

  test('mega commits aggregate into one Moderate finding with samples', () {
    final flagged =
        List.generate(8, (i) => 'hash$i - author (2026-01-01): big change $i');
    final findings = fc.fromMegaCommits(flagged);

    final finding = findings.single;
    expect(finding.category, 'commitHygiene');
    expect(finding.severity, Severity.moderate);
    expect(finding.metric, 'mega_commits');
    expect(finding.value, 8);
    // Evidence sample is bounded so the finding stays inline-sized.
    expect((finding.evidence['samples'] as List).length, 5);
    expect(finding.basis, contains('Nagappan'));
  });

  test('suspicious commits aggregate under their own metric', () {
    final findings = fc.fromSuspiciousCommits(['hash - a (d): hack around']);
    expect(findings.single.metric, 'suspicious_commits');
    expect(findings.single.value, 1);
  });

  test('clean history yields no findings', () {
    expect(fc.fromMegaCommits(const []), isEmpty);
    expect(fc.fromSuspiciousCommits(const []), isEmpty);
  });
}
