/// ----------------------------------------------------------------------------
/// clean_code_classifier.dart
/// ----------------------------------------------------------------------------
library;

import '../models/analysis_type.dart';

import 'package:rw_git/src/constants.dart';
import 'package:rw_git/src/models/clean_code_metrics_dto.dart';

import '../models/finding.dart';
import '../utils/path_key.dart';
import '../models/severity.dart';

/// Classifies per-file clean-code heuristics — excessive length, deep
/// nesting, long lines, magic numbers, duplicate lines — into findings.
/// One finding per file with issues: Elevated for any threshold crossed,
/// escalating to High when [cleanCodeHighSeverityIssueCount] or more
/// independent heuristics agree, since converging signals are a stronger
/// maintainability predictor than any single one.
class CleanCodeClassifier {
  const CleanCodeClassifier();

  /// Compact citation tag carried inline on every finding.
  static const String researchBasis =
      'Clean-code heuristics (Martin 2008; Fowler 1999; Koschke 2007)';

  /// Fuller research rationale carried only in the offloaded full report.
  static const String researchRationale =
      'Oversized files and deep nesting are the structural signature of '
      'Single Responsibility violations (Martin 2008); magic numbers hide '
      'intent behind literals (Fowler 1999); and duplicated lines are '
      'Type-1 clones whose copies drift apart under maintenance (Koschke '
      '2007). Multiple heuristics agreeing on one file compounds the risk.';

  List<Finding> classify(List<CleanCodeMetricsDto> files) {
    final findings = <Finding>[];
    for (final file in files) {
      if (file.issues.isEmpty) continue;
      final normalized = PathKey.normalize(file.filePath);
      final escalated = file.issues.length >= cleanCodeHighSeverityIssueCount;
      findings.add(Finding(
        category: 'cleanCode',
        source: [AnalysisType.cleanCode],
        severity: escalated ? Severity.high : Severity.elevated,
        subject: normalized,
        metric: 'clean_code_issues',
        value: file.issues.length,
        band: escalated
            ? '>= $cleanCodeHighSeverityIssueCount clean-code heuristics '
                'crossed'
            : 'clean-code threshold crossed',
        basis: researchBasis,
        rationale: researchRationale,
        message: '$normalized: ${file.issues.join(' ')}',
        evidence: {
          'total_lines': file.totalLines,
          'max_indentation_level': file.maxIndentationLevel,
          'long_lines': file.longLines,
          'magic_numbers': file.magicNumbers,
          'duplicate_lines': file.duplicateLines,
        },
      ));
    }
    return findings;
  }
}
