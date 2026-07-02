import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../../../constants.dart';
import '../../../models/file_lexical_metrics_dto.dart';
import 'agnostic/algorithms/cyclomatic_complexity.dart';
import 'agnostic/algorithms/maintainability_index.dart';
import 'agnostic/lexer/fsm_lexer.dart';
import 'agnostic/profiles/default_profiles.dart';

/// ----------------------------------------------------------------------------
/// bounded_lexical_metrics_sampler.dart
/// ----------------------------------------------------------------------------
/// Computes genuine lexical metrics (McCabe cyclomatic complexity and the
/// maintainability index) for a *bounded* sample of files so the report
/// meta-tools can include real complexity science without unbounded runtime:
/// only the top-N files by churn are lexed (complexity matters most where
/// change concentrates — Nagappan & Ball, ICSE 2005), oversized files are
/// skipped, and lexing runs in a background isolate (ADR-0003).
class BoundedLexicalMetricsSampler {
  const BoundedLexicalMetricsSampler();

  /// Lexes the [maxFiles] highest-churn entries of [fileChurn] that exist
  /// under [directory] and are at most [maxFileSizeBytes] long. Paths are
  /// resolved against the canonical [directory] and anything escaping it is
  /// skipped (SECURITY.md path-traversal rule). Unreadable or non-text files
  /// are skipped rather than failing the whole report.
  Future<List<FileLexicalMetricsDto>> sampleTopChurnFiles(
    String directory,
    Map<String, int> fileChurn, {
    int maxFiles = maxLexicalMetricsFilesPerReport,
    int maxFileSizeBytes = maxLexicalMetricsFileSizeBytes,
  }) async {
    final rankedByChurn = fileChurn.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final canonicalDirectory = p.canonicalize(directory);

    // Read sources on the main isolate (async IO), keyed by the original
    // churn path so findings join with churn findings on the same subject.
    final sourcesByChurnPath = <String, String>{};
    for (final entry in rankedByChurn) {
      if (sourcesByChurnPath.length >= maxFiles) break;
      final resolvedPath = p.isAbsolute(entry.key)
          ? p.canonicalize(entry.key)
          : p.canonicalize(p.join(directory, entry.key));
      if (!p.isWithin(canonicalDirectory, resolvedPath)) continue;

      final file = File(resolvedPath);
      try {
        if (!await file.exists()) continue;
        if (await file.length() > maxFileSizeBytes) continue;
        sourcesByChurnPath[entry.key] = await file.readAsString();
      } on FileSystemException {
        continue;
      }
    }
    if (sourcesByChurnPath.isEmpty) return const [];

    // Lex the whole sample off the main isolate: tokenizing up to N sizeable
    // files is CPU-bound and would otherwise block the event loop (>16ms).
    return Isolate.run(() => _computeLexicalMetrics(sourcesByChurnPath));
  }
}

List<FileLexicalMetricsDto> _computeLexicalMetrics(
    Map<String, String> sourcesByChurnPath) {
  final metrics = <FileLexicalMetricsDto>[];
  sourcesByChurnPath.forEach((churnPath, source) {
    final profile = DefaultProfiles.getProfileForFile(churnPath);
    final tokens = FsmLexer(source).tokenize();
    metrics.add(FileLexicalMetricsDto(
      filePath: churnPath,
      cyclomaticComplexity:
          CyclomaticComplexityAlgorithm().calculate(tokens, profile),
      maintainabilityIndex:
          MaintainabilityIndexAlgorithm().calculate(tokens, profile).score,
    ));
  });
  return metrics;
}
