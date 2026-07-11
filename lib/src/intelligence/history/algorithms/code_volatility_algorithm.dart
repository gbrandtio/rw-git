import 'dart:isolate';
import 'package:rw_git/src/core/process_runner.dart';
import 'package:rw_git/src/models/code_volatility_dto.dart';

/// ----------------------------------------------------------------------------
/// code_volatility_algorithm.dart
/// ----------------------------------------------------------------------------
/// Predicts defect-prone files based on relative code churn and the number of
/// unique authors (Conway's law applied to code). High volatility + many authors
/// is a strong predictor of bugs.
class CodeVolatilityAlgorithm {
  final ProcessRunner runner;

  CodeVolatilityAlgorithm(this.runner);

  /// Executes the Code Volatility analysis.
  /// Uses an Isolate to process the `git log` output asynchronously.
  Future<List<CodeVolatilityDto>> execute(
    String directory, {
    String? limit,
    String? since,
    String? until,
  }) async {
    // We need authors and files changed. `git log --name-only --format=AUTHOR:%an`
    final args = ['log', '--name-only', '--format=AUTHOR:%an'];
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
    if (rawOutput.isEmpty) return [];

    return await Isolate.run(() => _parseCodeVolatility(rawOutput));
  }
}

List<CodeVolatilityDto> _parseCodeVolatility(String rawLog) {
  final lines = rawLog.split('\n');

  final Map<String, int> fileChangeCount = {};
  final Map<String, Set<String>> fileAuthors = {};

  String currentAuthor = '';

  for (final line in lines) {
    if (line.trim().isEmpty) continue;

    if (line.startsWith('AUTHOR:')) {
      currentAuthor = line.substring(7).trim();
    } else {
      final file = line.trim();
      fileChangeCount[file] = (fileChangeCount[file] ?? 0) + 1;

      fileAuthors.putIfAbsent(file, () => {});
      if (currentAuthor.isNotEmpty) {
        fileAuthors[file]!.add(currentAuthor);
      }
    }
  }

  final results = <CodeVolatilityDto>[];

  for (final entry in fileChangeCount.entries) {
    final file = entry.key;
    final changes = entry.value;
    final authorsCount = fileAuthors[file]?.length ?? 1;

    // A simple heuristic for volatility score: (changes * authorsCount)
    // Files changed often by many different people are highly volatile.
    final score = (changes * authorsCount).toDouble();

    results.add(
      CodeVolatilityDto(
        filePath: file,
        totalChanges: changes,
        uniqueAuthors: authorsCount,
        volatilityScore: score,
      ),
    );
  }

  // Sort by volatility score descending
  results.sort((a, b) => b.volatilityScore.compareTo(a.volatilityScore));

  return results;
}
