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
        evidence: {
          'bus_factor': dto.busFactor,
          'total_developers_analyzed': dto.totalDevelopers,
          'top_author_percentage': pct,
        },
      ),
    ];
  }
}
