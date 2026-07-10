/// ----------------------------------------------------------------------------
/// lexical_complexity_classifier.dart
/// ----------------------------------------------------------------------------
library;

import '../models/analysis_type.dart';

import 'package:rw_git/src/constants.dart';
import 'package:rw_git/src/models/file_lexical_metrics_dto.dart';

import '../models/finding.dart';
import '../utils/path_key.dart';
import '../models/severity.dart';

/// Classifies the genuine per-file lexical complexity suite — McCabe
/// cyclomatic complexity, maintainability index, ABC score, NPath,
/// cognitive complexity, and the Halstead delivered-bugs estimate — using
/// the standard absolute bands. Unlike the diff-keyword `complexity`
/// category (repo-relative by necessity), these metrics are normalised
/// scores with industry-standard cut-offs, so absolute bands apply. One
/// finding is emitted per file, carrying whichever metric bands worst; the
/// full suite rides in evidence so no measured signal is dropped.
class LexicalComplexityClassifier {
  const LexicalComplexityClassifier();

  /// Compact citation tag carried inline on every finding.
  static const String researchBasis =
      'Lexical complexity suite bands (McCabe 1976; Coleman 1994; '
      'Fitzpatrick 1997; Nejmeh 1988; Campbell 2018; Halstead 1977)';

  /// Fuller research rationale carried only in the offloaded full report.
  static const String researchRationale =
      'Cyclomatic complexity counts independent execution paths; above 20 a '
      'unit is high-risk and above 50 effectively untestable (McCabe, IEEE '
      'TSE 1976). The maintainability index composes Halstead volume, '
      'complexity, and size; below 65 signals hard-to-maintain code '
      '(Coleman et al., ICSM 1994). The ABC score measures raw program size '
      'as the vector magnitude of assignments, branches, and conditions; '
      'above 30 a unit needs refactoring (Fitzpatrick 1997). NPath counts '
      'acyclic execution paths; above 200 path coverage is impractical '
      '(Nejmeh, CACM 1988). Cognitive complexity weights nesting, measuring '
      'understandability rather than testability (Campbell 2018). The '
      'Halstead delivered-bugs estimate (volume / 3000) approximates latent '
      'defects from program vocabulary and size (Halstead 1977).';

  List<Finding> classify(List<FileLexicalMetricsDto> files) {
    final findings = <Finding>[];
    for (final file in files) {
      final metricSeverities = _metricSeverities(file);
      final worst = metricSeverities
          .reduce((a, b) => b.severity.rank > a.severity.rank ? b : a);
      if (!worst.severity.isMaterial) continue;

      final normalized = PathKey.normalize(file.filePath);
      findings.add(Finding(
        category: 'lexicalComplexity',
        source: [AnalysisType.universalLexicalMetrics],
        severity: worst.severity,
        subject: normalized,
        metric: worst.metric,
        value: worst.value,
        band: worst.band,
        basis: researchBasis,
        rationale: researchRationale,
        message: '$normalized has ${worst.metric.replaceAll('_', ' ')} '
            '${worst.formattedValue} (${worst.band}); full complexity '
            'suite in evidence.',
        evidence: {
          'cyclomatic_complexity': file.cyclomaticComplexity,
          'maintainability_index': file.maintainabilityIndex,
          'abc_score': file.abcScore,
          'npath_complexity': file.npathComplexity,
          'cognitive_complexity': file.cognitiveComplexity,
          'halstead_delivered_bugs': file.halsteadDeliveredBugs,
        },
      ));
    }
    return findings;
  }

  /// Bands every metric of [file] independently, so the worst one drives
  /// the finding and the rest stay visible in evidence.
  List<_MetricSeverity> _metricSeverities(FileLexicalMetricsDto file) => [
        _MetricSeverity(
          metric: 'cyclomatic_complexity',
          value: file.cyclomaticComplexity,
          severity: _cyclomaticSeverity(file.cyclomaticComplexity),
          band: _cyclomaticBand(file.cyclomaticComplexity),
        ),
        _MetricSeverity(
          metric: 'maintainability_index',
          value: file.maintainabilityIndex,
          severity: _maintainabilitySeverity(file.maintainabilityIndex),
          band: _maintainabilityBand(file.maintainabilityIndex),
        ),
        _MetricSeverity(
          metric: 'abc_score',
          value: file.abcScore,
          severity: _abcSeverity(file.abcScore),
          band: _abcBand(file.abcScore),
        ),
        _MetricSeverity(
          metric: 'npath_complexity',
          value: file.npathComplexity,
          severity: _npathSeverity(file.npathComplexity),
          band: _npathBand(file.npathComplexity),
        ),
        _MetricSeverity(
          metric: 'cognitive_complexity',
          value: file.cognitiveComplexity,
          severity: _cognitiveSeverity(file.cognitiveComplexity),
          band: _cognitiveBand(file.cognitiveComplexity),
        ),
        _MetricSeverity(
          metric: 'halstead_delivered_bugs',
          value: file.halsteadDeliveredBugs,
          severity: _halsteadBugsSeverity(file.halsteadDeliveredBugs),
          band: _halsteadBugsBand(file.halsteadDeliveredBugs),
        ),
      ];

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

  Severity _abcSeverity(double abcScore) {
    if (abcScore > abcScoreHighThreshold) return Severity.high;
    if (abcScore > abcScoreElevatedThreshold) return Severity.elevated;
    return Severity.normal;
  }

  String _abcBand(double abcScore) {
    return abcScore > abcScoreHighThreshold
        ? 'ABC > $abcScoreHighThreshold (needs refactoring)'
        : 'ABC > $abcScoreElevatedThreshold (warrants review)';
  }

  Severity _npathSeverity(int npathComplexity) {
    if (npathComplexity > npathHighThreshold) return Severity.high;
    if (npathComplexity > npathElevatedThreshold) return Severity.elevated;
    return Severity.normal;
  }

  String _npathBand(int npathComplexity) {
    return npathComplexity > npathHighThreshold
        ? 'NPath > $npathHighThreshold (combinatorial path explosion)'
        : 'NPath > $npathElevatedThreshold (path coverage impractical)';
  }

  Severity _cognitiveSeverity(int cognitiveComplexity) {
    if (cognitiveComplexity > cognitiveComplexityHighThreshold) {
      return Severity.high;
    }
    if (cognitiveComplexity > cognitiveComplexityElevatedThreshold) {
      return Severity.elevated;
    }
    return Severity.normal;
  }

  String _cognitiveBand(int cognitiveComplexity) {
    return cognitiveComplexity > cognitiveComplexityHighThreshold
        ? 'cognitive complexity > $cognitiveComplexityHighThreshold '
            '(resists comprehension)'
        : 'cognitive complexity > $cognitiveComplexityElevatedThreshold '
            '(hard to understand)';
  }

  Severity _halsteadBugsSeverity(double deliveredBugs) {
    return deliveredBugs > halsteadDeliveredBugsElevatedThreshold
        ? Severity.elevated
        : Severity.normal;
  }

  String _halsteadBugsBand(double deliveredBugs) {
    return 'Halstead delivered-bugs estimate > '
        '$halsteadDeliveredBugsElevatedThreshold';
  }
}

/// One metric's banded reading for a file: which metric, its raw value,
/// the severity its band maps to, and the human-readable band label.
class _MetricSeverity {
  final String metric;
  final num value;
  final Severity severity;
  final String band;

  const _MetricSeverity({
    required this.metric,
    required this.value,
    required this.severity,
    required this.band,
  });

  /// Doubles are shown to one decimal; integer metrics as-is.
  String get formattedValue =>
      value is double ? (value as double).toStringAsFixed(1) : '$value';
}
