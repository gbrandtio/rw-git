/// ----------------------------------------------------------------------------
/// lexical_complexity_classifier.dart
/// ----------------------------------------------------------------------------
library;

import 'package:rw_git/src/constants.dart';
import 'package:rw_git/src/models/file_lexical_metrics_dto.dart';

import '../finding.dart';
import '../path_key.dart';
import '../severity.dart';

/// Classifies genuine per-file lexical metrics — McCabe cyclomatic
/// complexity and the maintainability index — using the standard absolute
/// bands. Unlike the diff-keyword `complexity` category (repo-relative by
/// necessity), these metrics are normalised scores with industry-standard
/// cut-offs, so absolute bands apply. One finding is emitted per file,
/// carrying whichever metric bands worse; the other rides in evidence.
class LexicalComplexityClassifier {
  const LexicalComplexityClassifier();

  /// Compact citation tag carried inline on every finding.
  static const String researchBasis =
      'McCabe complexity / maintainability bands (McCabe 1976; Coleman 1994)';

  /// Fuller research rationale carried only in the offloaded full report.
  static const String researchRationale =
      'Cyclomatic complexity counts independent execution paths; above 20 a '
      'unit is high-risk and above 50 effectively untestable (McCabe, IEEE '
      'TSE 1976). The maintainability index composes Halstead volume, '
      'complexity, and size; below 65 signals hard-to-maintain code '
      '(Coleman et al., ICSM 1994).';

  List<Finding> classify(List<FileLexicalMetricsDto> files) {
    final findings = <Finding>[];
    for (final file in files) {
      final complexitySeverity = _cyclomaticSeverity(file.cyclomaticComplexity);
      final maintainabilitySeverity =
          _maintainabilitySeverity(file.maintainabilityIndex);
      final severity =
          Severity.max(complexitySeverity, maintainabilitySeverity);
      if (!severity.isMaterial) continue;

      final complexityDominates =
          complexitySeverity.rank >= maintainabilitySeverity.rank;
      final normalized = PathKey.normalize(file.filePath);
      findings.add(Finding(
        category: 'lexicalComplexity',
        source: 'calculate_universal_lexical_metrics',
        severity: severity,
        subject: normalized,
        metric: complexityDominates
            ? 'cyclomatic_complexity'
            : 'maintainability_index',
        value: complexityDominates
            ? file.cyclomaticComplexity
            : file.maintainabilityIndex,
        band: complexityDominates
            ? _cyclomaticBand(file.cyclomaticComplexity)
            : _maintainabilityBand(file.maintainabilityIndex),
        basis: researchBasis,
        rationale: researchRationale,
        message: '$normalized has McCabe cyclomatic complexity '
            '${file.cyclomaticComplexity} and maintainability index '
            '${file.maintainabilityIndex.toStringAsFixed(1)}.',
        evidence: {
          'cyclomatic_complexity': file.cyclomaticComplexity,
          'maintainability_index': file.maintainabilityIndex,
        },
      ));
    }
    return findings;
  }

  Severity _cyclomaticSeverity(int cyclomaticComplexity) {
    if (cyclomaticComplexity > mccabeCriticalCyclomaticComplexityThreshold) {
      return Severity.critical;
    }
    if (cyclomaticComplexity > mccabeHighRiskCyclomaticComplexityThreshold) {
      return Severity.high;
    }
    if (cyclomaticComplexity > mccabeElevatedCyclomaticComplexityThreshold) {
      return Severity.elevated;
    }
    return Severity.normal;
  }

  String _cyclomaticBand(int cyclomaticComplexity) {
    if (cyclomaticComplexity > mccabeCriticalCyclomaticComplexityThreshold) {
      return '> $mccabeCriticalCyclomaticComplexityThreshold McCabe '
          '(effectively untestable)';
    }
    if (cyclomaticComplexity > mccabeHighRiskCyclomaticComplexityThreshold) {
      return '${mccabeHighRiskCyclomaticComplexityThreshold + 1}-'
          '$mccabeCriticalCyclomaticComplexityThreshold McCabe (high risk)';
    }
    return '${mccabeElevatedCyclomaticComplexityThreshold + 1}-'
        '$mccabeHighRiskCyclomaticComplexityThreshold McCabe (moderate)';
  }

  Severity _maintainabilitySeverity(double maintainabilityIndex) {
    if (maintainabilityIndex < maintainabilityIndexLowBandThreshold) {
      return Severity.high;
    }
    if (maintainabilityIndex < maintainabilityIndexModerateBandThreshold) {
      return Severity.elevated;
    }
    return Severity.normal;
  }

  String _maintainabilityBand(double maintainabilityIndex) {
    return maintainabilityIndex < maintainabilityIndexLowBandThreshold
        ? 'maintainability index < $maintainabilityIndexLowBandThreshold '
            '(low / needs refactoring)'
        : 'maintainability index < '
            '$maintainabilityIndexModerateBandThreshold (moderate)';
  }
}
