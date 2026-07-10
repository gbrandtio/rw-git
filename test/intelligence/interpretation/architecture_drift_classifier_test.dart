import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

/// The architecture-drift classifier carries the Garcia, Oliveira & Murta
/// (2009) architectural bad smells into the technical report and audit;
/// these tests pin the severity each smell and entanglement band maps to,
/// so a change is a deliberate ADR-0010 act.
void main() {
  const fc = FindingClassifier();

  ArchitectureDriftDto drift({
    List<ArchitecturalSmell> smells = const [],
    double couplingRatio = 0,
    double couplingDensity = 0,
  }) =>
      ArchitectureDriftDto(
        totalCommitsAnalyzed: 100,
        driftCommits: const [],
        couplingMatrix: const {},
        couplingRatio: couplingRatio,
        couplingDensity: couplingDensity,
        smells: smells,
      );

  test('God Component and Hub-Like Dependency band High', () {
    final findings = fc.fromArchitectureDrift(drift(smells: const [
      ArchitecturalSmell(
          type: 'God Component', layer: 'core', description: 'god'),
      ArchitecturalSmell(
          type: 'Hub-Like Dependency', layer: 'utils', description: 'hub'),
    ]));

    expect(findings, hasLength(2));
    for (final finding in findings) {
      expect(finding.severity, Severity.high);
      expect(finding.category, 'architectureDrift');
      expect(finding.source, [AnalysisType.architectureDrift]);
      expect(finding.basis, contains('Garcia'));
    }
    expect(findings.first.subject, 'core');
    expect(findings.last.subject, 'utils');
  });

  test('Scattered Functionality bands Moderate on the repository subject', () {
    final findings = fc.fromArchitectureDrift(drift(smells: const [
      ArchitecturalSmell(
          type: 'Scattered Functionality', count: 4, description: 'wide'),
    ]));

    expect(findings.single.severity, Severity.moderate);
    expect(findings.single.subject, 'repository');
    expect(findings.single.evidence['occurrences'], 4);
  });

  test('coupling ratio above 15% bands Elevated; at or below is silent', () {
    expect(fc.fromArchitectureDrift(drift(couplingRatio: 0.16)).single.severity,
        Severity.elevated);
    expect(fc.fromArchitectureDrift(drift(couplingRatio: 0.15)), isEmpty);
  });

  test('coupling density above 50% bands Elevated; at or below is silent', () {
    expect(fc.fromArchitectureDrift(drift(couplingDensity: 0.51)).single.metric,
        'coupling_density');
    expect(fc.fromArchitectureDrift(drift(couplingDensity: 0.5)), isEmpty);
  });
}
