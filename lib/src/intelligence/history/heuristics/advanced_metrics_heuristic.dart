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
  Future<AdvancedCodeQualityDto> calculateAdvancedMetrics(
    String directory, {
    String? limit,
    String? since,
    String? until,
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

    final result = await runner.run('git', args, workingDirectory: directory);
    evaluateProcessResult(result);
    final rawOutput = result.stdout?.toString() ?? '';

    return await Isolate.run(() => _parseAdvancedCodeQuality(rawOutput));
  }
}

AdvancedCodeQualityDto _parseAdvancedCodeQuality(String rawLog) {
  final lines = rawLog.split('\n');

  final fileComplexity = <String, int>{};
  final coChangeMatrix = <String, Map<String, int>>{};
  final dirCommits = <String, int>{};

  final controlFlowRegex = RegExp(r'\b(if|for|while|switch|&&|\|\||\?)\b');

  List<String> currentCommitFiles = [];
  String currentFile = '';

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
    } else if (line.startsWith('--- a/')) {
      final fileName = line.substring(6).trim();
      if (fileName != '/dev/null') {
        currentFile = fileName;
        if (!currentCommitFiles.contains(fileName)) {
          currentCommitFiles.add(fileName);
        }
      }
    } else if (line.startsWith('+') && !line.startsWith('+++')) {
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
