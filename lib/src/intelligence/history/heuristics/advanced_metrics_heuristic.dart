import 'dart:isolate';
import 'package:rw_git/src/core/process_runner.dart';
import 'package:rw_git/src/models/advanced_code_quality_dto.dart';

/// ----------------------------------------------------------------------------
/// advanced_metrics_heuristic.dart
/// ----------------------------------------------------------------------------
class AdvancedMetricsHeuristic {
  final ProcessRunner runner;

  AdvancedMetricsHeuristic(this.runner);

  /// Computes advanced codebase metrics such as cyclomatic complexity
  /// approximations, co-change matrices, and architectural
  /// distribution.
  ///
  /// When [targetFiles] is provided, the history walk is limited to commits
  /// touching those paths (git pathspec) and every reported metric —
  /// complexity, co-change matrix, architecture distribution — is restricted
  /// to exactly those files. Callers scoping analysis to a specific file set
  /// (e.g. a PR's modified files) avoid paying for a full-repository
  /// `git log -p` scan.
  Future<AdvancedCodeQualityDto> calculateAdvancedMetrics(
    String directory, {
    String? limit,
    String? since,
    String? until,
    List<String>? targetFiles,
  }) async {
    final args = ['log', '-p', '--format=COMMIT:%H'];
    if (limit != null) {
      args.insert(1, '-n');
      args.insert(2, limit);
    }
    if (since != null) {
      args.add('--since=$since');
    }
    if (until != null) {
      args.add('--until=$until');
    }
    if (targetFiles != null && targetFiles.isNotEmpty) {
      args.add('--');
      args.addAll(targetFiles);
    }

    final result = await runner.run('git', args, workingDirectory: directory);
    evaluateProcessResult(result);
    final rawOutput = result.stdout?.toString() ?? '';

    // targetFiles is an exact result restriction, not just a commit
    // pre-filter (mirrors ChurnHeuristic's own targetFiles handling).
    final targetSet = (targetFiles != null && targetFiles.isNotEmpty)
        ? targetFiles.toSet()
        : null;

    return await Isolate.run(
      () => _parseAdvancedCodeQuality(rawOutput, targetSet),
    );
  }
}

AdvancedCodeQualityDto _parseAdvancedCodeQuality(
  String rawLog,
  Set<String>? targetFiles,
) {
  final lines = rawLog.split('\n');

  final fileComplexity = <String, int>{};
  final coChangeMatrix = <String, Map<String, int>>{};
  final dirCommits = <String, int>{};

  final controlFlowRegex = RegExp(r'\b(if|for|while|switch|&&|\|\||\?)\b');

  List<String> currentCommitFiles = [];
  String currentFile = '';

  bool inScope(String file) =>
      targetFiles == null || targetFiles.contains(file);

  void trackFile(String file) {
    if (!inScope(file)) return;
    if (!currentCommitFiles.contains(file)) {
      currentCommitFiles.add(file);
    }
  }

  void flushCommit() {
    if (currentCommitFiles.isNotEmpty) {
      for (int i = 0; i < currentCommitFiles.length; i++) {
        final f1 = currentCommitFiles[i];
        coChangeMatrix.putIfAbsent(f1, () => {});
        for (final f2 in currentCommitFiles) {
          if (f1 != f2) {
            coChangeMatrix[f1]![f2] = (coChangeMatrix[f1]![f2] ?? 0) + 1;
          }
        }

        final parts = f1.split('/');
        if (parts.length > 1) {
          final topLevelDir = parts[0];
          dirCommits[topLevelDir] = (dirCommits[topLevelDir] ?? 0) + 1;
        }
      }
    }
    currentCommitFiles.clear();
  }

  for (final line in lines) {
    if (line.trim().isEmpty) continue;

    if (line.startsWith('COMMIT:')) {
      flushCommit();
      currentFile = '';
    } else if (line.startsWith('--- ')) {
      // Pre-image header. Reset attribution at every file boundary so a new
      // file's added lines (pre-image `/dev/null`) are never credited to the
      // previous file in the diff; the post-image `+++` header below decides
      // where added lines belong.
      currentFile = '';
      if (line.startsWith('--- a/')) {
        trackFile(line.substring(6).trim());
      }
    } else if (line.startsWith('+++ ')) {
      if (line.startsWith('+++ b/')) {
        final fileName = line.substring(6).trim();
        // Complexity of added lines keys on the post-image path, so newly
        // added files are attributed to themselves rather than skipped.
        if (inScope(fileName)) {
          currentFile = fileName;
        }
        trackFile(fileName);
      }
    } else if (line.startsWith('+')) {
      if (currentFile.isNotEmpty) {
        final matches = controlFlowRegex.allMatches(line);
        if (matches.isNotEmpty) {
          fileComplexity[currentFile] =
              (fileComplexity[currentFile] ?? 0) + matches.length;
        }
      }
    }
  }
  flushCommit();

  final architectureDistribution = <String, double>{};
  final totalDirCommits = dirCommits.values.fold<int>(
    0,
    (sum, val) => sum + val,
  );
  if (totalDirCommits > 0) {
    for (final entry in dirCommits.entries) {
      architectureDistribution[entry.key] = double.parse(
        (entry.value / totalDirCommits).toStringAsFixed(3),
      );
    }
  }

  return AdvancedCodeQualityDto(
    fileComplexity: fileComplexity,
    coChangeMatrix: coChangeMatrix,
    architectureDistribution: architectureDistribution,
  );
}
