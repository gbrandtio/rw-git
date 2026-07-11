import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

/// The Dart AST classifier carries Tarjan-SCC import-cycle detection into
/// the technical report and audit; these tests pin the High severity every
/// cycle maps to (Tarjan 1972; Lakhotia 1993), so a change is a deliberate
/// ADR-0010 act.
void main() {
  const fc = FindingClassifier();

  test('each cycle bands High with the sorted members as evidence', () {
    final findings = fc.fromImportCycles([
      ['lib/b.dart', 'lib/a.dart'],
    ]);

    final finding = findings.single;
    expect(finding.severity, Severity.high);
    expect(finding.category, 'dartAst');
    expect(finding.source, [AnalysisType.dartAstQuality]);
    expect(finding.subject, 'lib/a.dart');
    expect(finding.value, 2);
    expect(finding.evidence['cycle_members'], ['lib/a.dart', 'lib/b.dart']);
  });

  test('no cycles, no findings', () {
    expect(fc.fromImportCycles(const []), isEmpty);
  });
}
