import 'dart:isolate';
import '../core/process_runner.dart';
import '../models/logical_coupling_dto.dart';

/// ----------------------------------------------------------------------------
/// logical_coupling_algorithm.dart
/// ----------------------------------------------------------------------------
/// Algorithm to detect implicit dependencies between files that frequently
/// change together (co-change analysis).
class LogicalCouplingAlgorithm {
  final ProcessRunner runner;

  LogicalCouplingAlgorithm(this.runner);

  /// Executes the logical coupling analysis.
  /// Uses an Isolate to process the `git log` output asynchronously.
  Future<List<LogicalCouplingDto>> execute(
    String directory, {
    String? limit,
    int minCoChanges = 3,
  }) async {
    final args = ['log', '--name-only', '--format=COMMIT:%H'];
    if (limit != null) {
      args.insert(1, '-n');
      args.insert(2, limit);
    }

    final result = await runner.run('git', args, workingDirectory: directory);
    evaluateProcessResult(result);

    final rawOutput = result.stdout?.toString() ?? '';
    if (rawOutput.isEmpty) return [];

    return await Isolate.run(
        () => _parseLogicalCoupling(rawOutput, minCoChanges));
  }
}

/// Isolate entry point for parsing and calculating logical coupling.
List<LogicalCouplingDto> _parseLogicalCoupling(
    String rawLog, int minCoChanges) {
  final lines = rawLog.split('\n');
  final List<List<String>> transactions = [];
  List<String> currentTransaction = [];

  // Parse commits into transactions
  for (final line in lines) {
    if (line.trim().isEmpty) continue;

    if (line.startsWith('COMMIT:')) {
      if (currentTransaction.isNotEmpty) {
        transactions.add(currentTransaction);
      }
      currentTransaction = [];
    } else {
      currentTransaction.add(line.trim());
    }
  }
  if (currentTransaction.isNotEmpty) {
    transactions.add(currentTransaction);
  }

  // Count co-changes
  final Map<String, int> coChangeMap = {};
  final Map<String, int> fileChangeCount = {}; // For calculating confidence

  for (final transaction in transactions) {
    // Only care about transactions with more than 1 file
    if (transaction.length < 2) continue;

    // Track total times each file was changed
    for (final file in transaction) {
      fileChangeCount[file] = (fileChangeCount[file] ?? 0) + 1;
    }

    // Generate pairs (A, B) such that A < B to ensure consistency
    for (int i = 0; i < transaction.length; i++) {
      for (int j = i + 1; j < transaction.length; j++) {
        final f1 = transaction[i];
        final f2 = transaction[j];
        if (f1 == f2) continue;

        final pair = (f1.compareTo(f2) < 0) ? '$f1||$f2' : '$f2||$f1';
        coChangeMap[pair] = (coChangeMap[pair] ?? 0) + 1;
      }
    }
  }

  // Filter and build results
  final results = <LogicalCouplingDto>[];
  for (final entry in coChangeMap.entries) {
    if (entry.value >= minCoChanges) {
      final parts = entry.key.split('||');
      final fileA = parts[0];
      final fileB = parts[1];

      // Calculate confidence as the probability that A changes when B changes (or vice versa)
      // Pick the max confidence direction
      final countA = fileChangeCount[fileA] ?? 1;
      final countB = fileChangeCount[fileB] ?? 1;
      final confA = entry.value / countA;
      final confB = entry.value / countB;
      final maxConfidence = confA > confB ? confA : confB;

      results.add(LogicalCouplingDto(
        fileA: fileA,
        fileB: fileB,
        coChangeCount: entry.value,
        confidence: maxConfidence,
      ));
    }
  }

  // Sort by coChangeCount descending
  results.sort((a, b) => b.coChangeCount.compareTo(a.coChangeCount));

  return results;
}
