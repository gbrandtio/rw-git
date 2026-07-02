import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

/// Merge-conflict prediction findings for the code-review report: textual
/// conflicts (git merge-tree) outrank logical overlaps, and a file must not
/// be reported twice when both signals hit it.
void main() {
  const fc = FindingClassifier();

  test('textual conflicts band High, logical overlaps Elevated', () {
    final findings = fc.fromConflictRisk({
      'merge_base': ['abc'],
      'conflicting_files': ['lib/overlap.dart'],
      'textual_conflicting_files': ['lib/conflict.dart'],
    });
    final bySubject = {for (final f in findings) f.subject: f};

    expect(bySubject['lib/conflict.dart']!.severity, Severity.high);
    expect(bySubject['lib/conflict.dart']!.metric, 'textual_conflict');
    expect(bySubject['lib/overlap.dart']!.severity, Severity.elevated);
    expect(bySubject['lib/overlap.dart']!.metric, 'logical_overlap');
    expect(bySubject['lib/conflict.dart']!.basis, contains('Brun'));
  });

  test('a textual conflict suppresses the duplicate logical-overlap finding',
      () {
    final findings = fc.fromConflictRisk({
      'conflicting_files': ['lib/x.dart'],
      'textual_conflicting_files': ['lib/x.dart'],
    });
    expect(findings.length, 1);
    expect(findings.single.metric, 'textual_conflict');
  });

  test('no overlap yields no findings', () {
    expect(
        fc.fromConflictRisk({
          'conflicting_files': [],
          'textual_conflicting_files': [],
        }),
        isEmpty);
  });
}
