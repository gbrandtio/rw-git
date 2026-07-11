import 'dart:isolate';

import '../../constants.dart';
import '../../models/clean_code_metrics_dto.dart';

/// ----------------------------------------------------------------------------
/// clean_code_analyzer.dart
/// ----------------------------------------------------------------------------
/// Language-agnostic clean-code heuristics for one source file: excessive
/// length and deep nesting (Martin 2008), magic-number literals (Fowler
/// 1999), long lines, and Type-1 duplicate lines (Koschke 2007). Pure —
/// takes source text, returns a [CleanCodeMetricsDto] — so it is shared,
/// library-first (ADR-0005), by the `analyze_clean_code` MCP tool and the
/// report meta-tools' bounded top-churn sample.
class CleanCodeAnalyzer {
  const CleanCodeAnalyzer();

  /// Matches numeric literals that are not 0, 1, or -1, and not inside a
  /// string or comment (best-effort lexical approximation).
  static final RegExp _magicNumberRegex = RegExp(
    r'(?<!["\w.])\b([2-9]\d*|\d{2,})\b(?!["w.])',
  );

  /// Strips inline comments before scanning (`// ...` and `# ...`).
  static final RegExp _commentStripRegex = RegExp(r'//.*$|#.*$');

  /// Analyzes already-read [sources] (path -> source text) off the main
  /// isolate: scanning up to N sizeable files line-by-line is CPU-bound and
  /// would otherwise block the event loop (>16ms, ADR-0003). Used by the
  /// report orchestrator on the same bounded top-churn sample the lexical
  /// sampler reads.
  Future<List<CleanCodeMetricsDto>> analyzeSources(
    Map<String, String> sources,
  ) async {
    if (sources.isEmpty) return const [];
    return Isolate.run(
      () => sources.entries
          .map((entry) => analyzeSource(entry.key, entry.value))
          .toList(),
    );
  }

  CleanCodeMetricsDto analyzeSource(String filePath, String source) {
    // Mirror `File.readAsLines` semantics: normalise CRLF and do not count
    // a trailing newline as an extra empty line.
    final normalized = source.replaceAll('\r\n', '\n');
    final trimmed = normalized.endsWith('\n')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
    final lines = trimmed.split('\n');
    final totalLines = lines.length;

    int maxIndentation = 0;
    int longLines = 0;
    int magicNumbers = 0;
    int duplicateLines = 0;
    final seenLines = <String, int>{};

    for (final line in lines) {
      if (line.length > cleanCodeLongLineLength) {
        longLines++;
      }

      int indentSpaces = 0;
      for (int i = 0; i < line.length; i++) {
        if (line[i] == ' ') {
          indentSpaces++;
        } else if (line[i] == '\t') {
          indentSpaces += cleanCodeIndentationUnitSpaces;
        } else {
          break;
        }
      }
      final indentLevel = indentSpaces ~/ cleanCodeIndentationUnitSpaces;
      if (indentLevel > maxIndentation) {
        maxIndentation = indentLevel;
      }

      final stripped = line.replaceAll(_commentStripRegex, '').trim();
      if (stripped.isNotEmpty) {
        magicNumbers += _magicNumberRegex.allMatches(stripped).length;
        if (stripped.length > cleanCodeDuplicateLineMinimumLength) {
          seenLines[stripped] = (seenLines[stripped] ?? 0) + 1;
        }
      }
    }

    for (final count in seenLines.values) {
      if (count > 1) duplicateLines += count - 1;
    }

    final issues = <String>[];
    if (totalLines > cleanCodeFileLengthThreshold) {
      issues.add(
        'File is too long ($totalLines lines), indicating potential '
        'violation of Single Responsibility Principle.',
      );
    }
    if (maxIndentation >= cleanCodeNestingDepthThreshold) {
      issues.add(
        'Deep nesting detected (max $maxIndentation levels). '
        'Consider extracting methods to reduce complexity.',
      );
    }
    if (longLines > totalLines * cleanCodeLongLineShareThreshold) {
      issues.add(
        '$longLines lines are longer than $cleanCodeLongLineLength '
        'characters, which may affect readability.',
      );
    }
    if (magicNumbers > cleanCodeMagicNumberThreshold) {
      issues.add(
        '$magicNumbers magic number literals detected. Replace with '
        'named constants to improve clarity.',
      );
    }
    if (totalLines > 0 &&
        duplicateLines > totalLines * cleanCodeDuplicateLineShareThreshold) {
      issues.add(
        '$duplicateLines duplicate lines detected (Type-1 clones). '
        'Extract the repeated logic into a shared function.',
      );
    }

    return CleanCodeMetricsDto(
      filePath: filePath,
      totalLines: totalLines,
      maxIndentationLevel: maxIndentation,
      longLines: longLines,
      magicNumbers: magicNumbers,
      duplicateLines: duplicateLines,
      issues: issues,
    );
  }
}
