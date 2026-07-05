/// clean_code_metrics_dto.dart
/// Per-file clean-code heuristic metrics (Martin 2008; Fowler 1999;
/// Koschke 2007): size, nesting, long lines, magic numbers, duplicate
/// lines, and the human-readable issues those measurements imply.
class CleanCodeMetricsDto {
  /// Path of the analyzed file, as supplied by the caller (repository
  /// relative in report use, so findings join with churn on the same key).
  final String filePath;

  final int totalLines;
  final int maxIndentationLevel;
  final int longLines;
  final int magicNumbers;
  final int duplicateLines;

  /// Human-readable descriptions of every threshold the file crossed.
  final List<String> issues;

  const CleanCodeMetricsDto({
    required this.filePath,
    required this.totalLines,
    required this.maxIndentationLevel,
    required this.longLines,
    required this.magicNumbers,
    required this.duplicateLines,
    required this.issues,
  });

  Map<String, dynamic> toJson() => {
        'file_path': filePath,
        'total_lines': totalLines,
        'max_indentation_level': maxIndentationLevel,
        'long_lines': longLines,
        'magic_numbers': magicNumbers,
        'duplicate_lines': duplicateLines,
        'clean_code_issues': issues,
      };
}
