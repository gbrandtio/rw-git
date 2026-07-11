/// ----------------------------------------------------------------------------
/// architecture_drift_classifier.dart
/// ----------------------------------------------------------------------------
library;

import '../models/analysis_type.dart';

import 'package:rw_git/src/constants.dart';
import 'package:rw_git/src/models/architecture_drift_dto.dart';

import '../models/finding.dart';
import '../models/severity.dart';

/// Classifies architecture-drift analysis into findings: the architectural
/// bad smells of Garcia, Oliveira & Murta (2009) — God Component and
/// Hub-Like Dependency band High, Scattered Functionality Moderate — plus
/// repo-level entanglement bands on the coupling ratio (share of commits
/// violating layer boundaries) and coupling density (fraction of layer
/// pairs coupled at all).
class ArchitectureDriftClassifier {
  const ArchitectureDriftClassifier();

  List<Finding> classify(ArchitectureDriftDto drift) {
    final findings = <Finding>[];

    for (final smell in drift.smells) {
      final isScattered = smell.type == 'Scattered Functionality';
      findings.add(
        Finding(
          category: 'architectureDrift',
          source: [AnalysisType.architectureDrift],
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
          evidence: {
            'smell_type': smell.type,
            if (smell.count != null) 'occurrences': smell.count,
            'commits_with_drift': drift.driftCommits.length,
            'total_commits_analyzed': drift.totalCommitsAnalyzed,
          },
        ),
      );
    }

    if (drift.couplingRatio > couplingRatioElevatedThreshold) {
      findings.add(
        Finding(
          category: 'architectureDrift',
          source: [AnalysisType.architectureDrift],
          severity: Severity.elevated,
          subject: 'repository',
          metric: 'coupling_ratio',
          value: double.parse(drift.couplingRatio.toStringAsFixed(3)),
          band: '> ${(couplingRatioElevatedThreshold * 100).round()}% of '
              'commits cross layer boundaries',
          evidence: {
            'commits_with_drift': drift.driftCommits.length,
            'total_commits_analyzed': drift.totalCommitsAnalyzed,
          },
        ),
      );
    }

    if (drift.couplingDensity > couplingDensityElevatedThreshold) {
      findings.add(
        Finding(
          category: 'architectureDrift',
          source: [AnalysisType.architectureDrift],
          severity: Severity.elevated,
          subject: 'repository',
          metric: 'coupling_density',
          value: double.parse(drift.couplingDensity.toStringAsFixed(3)),
          band: '> ${(couplingDensityElevatedThreshold * 100).round()}% of '
              'layer pairs coupled',
          evidence: {
            'coupling_matrix_layers': drift.couplingMatrix.keys.toList(),
          },
        ),
      );
    }

    return findings;
  }
}
