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

  List<Finding> classify(List<CleanCodeMetricsDto> files) {
    final findings = <Finding>[];
    for (final file in files) {
      if (file.issues.isEmpty) continue;
      final normalized = PathKey.normalize(file.filePath);
      final escalated = file.issues.length >= cleanCodeHighSeverityIssueCount;
      findings.add(
        Finding(
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
          evidence: {
            'total_lines': file.totalLines,
            'max_indentation_level': file.maxIndentationLevel,
            'long_lines': file.longLines,
            'magic_numbers': file.magicNumbers,
            'duplicate_lines': file.duplicateLines,
          },
        ),
      );
    }
    return findings;
  }
}
