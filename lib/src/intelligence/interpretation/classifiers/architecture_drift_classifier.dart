/// ----------------------------------------------------------------------------
/// architecture_drift_classifier.dart
/// ----------------------------------------------------------------------------
library;

import 'package:rw_git/src/constants.dart';
import 'package:rw_git/src/models/architecture_drift_dto.dart';

import '../finding.dart';
import '../severity.dart';

/// Classifies architecture-drift analysis into findings: the architectural
/// bad smells of Garcia, Oliveira & Murta (2009) — God Component and
/// Hub-Like Dependency band High, Scattered Functionality Moderate — plus
/// repo-level entanglement bands on the coupling ratio (share of commits
/// violating layer boundaries) and coupling density (fraction of layer
/// pairs coupled at all).
class ArchitectureDriftClassifier {
  const ArchitectureDriftClassifier();

  /// Compact citation tag carried inline on every finding.
  static const String researchBasis =
      'Architectural bad smells (Garcia et al. 2009; Perry & Wolf 1992)';

  /// Fuller research rationale carried only in the offloaded full report.
  static const String researchRationale =
      'Commits that repeatedly span multiple architectural layers are the '
      'historical signature of eroding boundaries (Perry & Wolf 1992). '
      'Garcia, Oliveira & Murta (2009) catalogue the recurring shapes of '
      'that erosion: a God Component absorbing cross-cutting concerns, a '
      'hub layer coupled to most others, and functionality scattered '
      'across layers no single one owns.';

  List<Finding> classify(ArchitectureDriftDto drift) {
    final findings = <Finding>[];

    for (final smell in drift.smells) {
      final isScattered = smell.type == 'Scattered Functionality';
      findings.add(Finding(
        category: 'architectureDrift',
        source: 'analyze_architecture_drift',
        severity: isScattered ? Severity.moderate : Severity.high,
        subject: smell.layer ?? 'repository',
        metric: 'architectural_smell',
        value: smell.type,
        band: isScattered
            ? '>= $scatteredFunctionalityLayerCount layers per commit'
            : smell.type == 'God Component'
                ? '> ${(godComponentDriftShareThreshold * 100).round()}% of '
                    'drift commits'
                : '>= half of layers coupled',
        basis: researchBasis,
        rationale: researchRationale,
        message: smell.description,
        evidence: {
          'smell_type': smell.type,
          if (smell.count != null) 'occurrences': smell.count,
          'commits_with_drift': drift.driftCommits.length,
          'total_commits_analyzed': drift.totalCommitsAnalyzed,
        },
      ));
    }

    if (drift.couplingRatio > couplingRatioElevatedThreshold) {
      findings.add(Finding(
        category: 'architectureDrift',
        source: 'analyze_architecture_drift',
        severity: Severity.elevated,
        subject: 'repository',
        metric: 'coupling_ratio',
        value: double.parse(drift.couplingRatio.toStringAsFixed(3)),
        band: '> ${(couplingRatioElevatedThreshold * 100).round()}% of '
            'commits cross layer boundaries',
        basis: researchBasis,
        rationale: researchRationale,
        message: '${(drift.couplingRatio * 100).toStringAsFixed(1)}% of '
            'analyzed commits modify more than one architectural layer — '
            'the declared boundaries are not containing change.',
        evidence: {
          'commits_with_drift': drift.driftCommits.length,
          'total_commits_analyzed': drift.totalCommitsAnalyzed,
        },
      ));
    }

    if (drift.couplingDensity > couplingDensityElevatedThreshold) {
      findings.add(Finding(
        category: 'architectureDrift',
        source: 'analyze_architecture_drift',
        severity: Severity.elevated,
        subject: 'repository',
        metric: 'coupling_density',
        value: double.parse(drift.couplingDensity.toStringAsFixed(3)),
        band: '> ${(couplingDensityElevatedThreshold * 100).round()}% of '
            'layer pairs coupled',
        basis: researchBasis,
        rationale: researchRationale,
        message: '${(drift.couplingDensity * 100).toStringAsFixed(1)}% of '
            'possible layer pairs co-change — the architecture behaves as '
            'an entangled whole rather than independent layers.',
        evidence: {
          'coupling_matrix_layers': drift.couplingMatrix.keys.toList(),
        },
      ));
    }

    return findings;
  }
}
