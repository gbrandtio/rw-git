/// ----------------------------------------------------------------------------
/// bus_factor_classifier.dart
/// ----------------------------------------------------------------------------
library;

import '../models/analysis_type.dart';

import 'package:rw_git/src/models/bus_factor_dto.dart';

import '../models/finding.dart';
import '../models/severity.dart';

/// Classifies repository-wide contribution concentration (bus factor) into a
/// severity band using the ownership-concentration thresholds.
class BusFactorClassifier {
  const BusFactorClassifier();

  /// Compact citation tag carried inline on every finding.
  static const String researchBasis =
      'Truck-factor estimation (Avelino et al. 2016; Conway 1968)';

  /// Fuller research rationale carried only in the offloaded full report.
  static const String researchRationale =
      'Contribution concentration approximates the truck factor — the '
      'number of developers whose loss stalls the project (Avelino et al., '
      'SANER 2016); organisational structure mirrors code structure '
      '(Conway, 1968), so a dominant author is a delivery risk.';

  List<Finding> classify(BusFactorDto dto) {
    if (dto.topContributors.isEmpty) return const [];
    final top = dto.topContributors.first;
    final share = top.percentage; // 0..1

    final Severity severity;
    final String band;
    if (share > 0.50) {
      severity = Severity.critical;
      band = '> 50% of commits';
    } else if (share >= 0.30) {
      severity = Severity.moderate;
      band = '30-50% of commits';
    } else {
      severity = Severity.healthy;
      band = '< 30% of commits';
    }

    final pct = (share * 100).toStringAsFixed(1);
    return [
      Finding(
        category: 'busFactor',
        source: [AnalysisType.busFactor],
        severity: severity,
        subject: top.author,
        metric: 'contribution_percentage',
        value: double.parse((share * 100).toStringAsFixed(2)),
        band: band,
        basis: researchBasis,
        rationale: researchRationale,
        message: severity.isMaterial
            ? '${top.author} authored $pct% of analysed commits '
                '(bus factor ${dto.busFactor}).'
            : 'Contributions are well distributed '
                '(top author $pct%, bus factor ${dto.busFactor}).',
        evidence: {
          'bus_factor': dto.busFactor,
          'total_developers_analyzed': dto.totalDevelopers,
          'top_author_percentage': pct,
        },
      ),
    ];
  }
}
