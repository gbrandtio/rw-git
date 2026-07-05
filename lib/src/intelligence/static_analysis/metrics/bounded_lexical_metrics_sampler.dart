import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../../../constants.dart';
import '../../../models/file_lexical_metrics_dto.dart';
import '../../source_file_filter.dart';
import 'agnostic/algorithms/abc_score.dart';
import 'agnostic/algorithms/cognitive_complexity.dart';
import 'agnostic/algorithms/cyclomatic_complexity.dart';
import 'agnostic/algorithms/halstead_complexity.dart';
import 'agnostic/algorithms/maintainability_index.dart';
import 'agnostic/algorithms/npath_complexity.dart';
import 'agnostic/lexer/fsm_lexer.dart';
import 'agnostic/profiles/default_profiles.dart';

/// ----------------------------------------------------------------------------
/// bounded_lexical_metrics_sampler.dart
/// ----------------------------------------------------------------------------
/// Computes the genuine lexical complexity suite — McCabe cyclomatic
/// complexity, maintainability index, ABC score (Fitzpatrick 1997), NPath
/// (Nejmeh 1988), cognitive complexity (Campbell 2018), and the Halstead
/// delivered-bugs estimate (Halstead 1977) — for a *bounded* sample of files
/// so the report meta-tools can include real complexity science without
/// unbounded runtime: only the top-N files by churn are lexed (complexity
/// matters most where change concentrates — Nagappan & Ball, ICSE 2005),
/// oversized files are skipped, and lexing runs in a background isolate
/// (ADR-0003).
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
    final sourcesByChurnPath = await readTopChurnSources(
      directory,
      fileChurn,
      maxFiles: maxFiles,
      maxFileSizeBytes: maxFileSizeBytes,
    );
    return lexSources(sourcesByChurnPath);
  }

  /// Lexes already-read [sources] (churn path -> source text) off the main
  /// isolate: tokenizing up to N sizeable files is CPU-bound and would
  /// otherwise block the event loop (>16ms, ADR-0003). Split from the file
  /// reading so the report orchestrator can reuse one bounded sample for
  /// several analyses.
  Future<List<FileLexicalMetricsDto>> lexSources(
      Map<String, String> sources) async {
    if (sources.isEmpty) return const [];
    return Isolate.run(() => _computeLexicalMetrics(sources));
  }

  /// Reads the [maxFiles] highest-churn sources under [directory], keyed by
  /// the original churn path so downstream findings join with churn findings
  /// on the same subject. Non-source files ([SourceFileFilter]) are skipped
  /// so prose and config never occupy the bounded sample's slots. Shared by
  /// the lexical and clean-code report samplers so both analyze the
  /// identical bounded sample.
  Future<Map<String, String>> readTopChurnSources(
    String directory,
    Map<String, int> fileChurn, {
    int maxFiles = maxLexicalMetricsFilesPerReport,
    int maxFileSizeBytes = maxLexicalMetricsFileSizeBytes,
  }) async {
    final rankedByChurn = fileChurn.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final canonicalDirectory = p.canonicalize(directory);

    // Read sources on the main isolate (async IO).
    final sourcesByChurnPath = <String, String>{};
    for (final entry in rankedByChurn) {
      if (sourcesByChurnPath.length >= maxFiles) break;
      if (!SourceFileFilter.isSource(entry.key)) continue;
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
    return sourcesByChurnPath;
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
      abcScore: AbcScoreAlgorithm().calculate(tokens, profile).score,
      npathComplexity: NpathComplexityAlgorithm().calculate(tokens, profile),
      cognitiveComplexity:
          CognitiveComplexityAlgorithm().calculate(tokens, profile),
      halsteadDeliveredBugs: HalsteadComplexityAlgorithm()
          .calculate(tokens, profile)
          .deliveredBugs,
    ));
  });
  return metrics;
}
