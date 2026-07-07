import 'dart:isolate';
import 'package:rw_git/src/core/process_runner.dart';
import 'package:rw_git/src/models/bus_factor_dto.dart';

/// ----------------------------------------------------------------------------
/// bus_factor_algorithm.dart
/// ----------------------------------------------------------------------------
/// Calculates the Bus Factor (Truck Factor) for a repository.
/// The Bus Factor is the minimum number of team members that have to suddenly
/// disappear from a project before the project stalls due to lack of knowledge.
class BusFactorAlgorithm {
  final ProcessRunner runner;

  BusFactorAlgorithm(this.runner);

  /// Executes the Bus Factor analysis based on commit counts.
  /// Uses an Isolate to process the `git log` output asynchronously.
  Future<BusFactorDto> execute(
    String directory, {
    String? limit,
    String? since,
    String? until,
    double knowledgeThreshold = 0.50, // 50% of contributions
  }) async {
    final args = ['log', '--format=%an'];
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
    if (rawOutput.isEmpty) {
      return BusFactorDto(
          busFactor: 0, totalDevelopers: 0, topContributors: []);
    }

    return await Isolate.run(
        () => _parseBusFactor(rawOutput, knowledgeThreshold));
  }
}

BusFactorDto _parseBusFactor(String rawLog, double threshold) {
  final lines = rawLog.split('\n');
  final Map<String, int> authorCommits = {};
  int totalCommits = 0;

  for (final line in lines) {
    final author = line.trim();
    if (author.isNotEmpty) {
      authorCommits[author] = (authorCommits[author] ?? 0) + 1;
      totalCommits++;
    }
  }

  if (totalCommits == 0) {
    return BusFactorDto(busFactor: 0, totalDevelopers: 0, topContributors: []);
  }

  final sortedAuthors = authorCommits.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  int busFactor = 0;
  int cumulativeCommits = 0;
  final List<DeveloperContribution> contributors = [];

  for (final entry in sortedAuthors) {
    cumulativeCommits += entry.value;
    busFactor++;

    contributors.add(DeveloperContribution(
      author: entry.key,
      contributions: entry.value,
      percentage: entry.value / totalCommits,
    ));

    if ((cumulativeCommits / totalCommits) >= threshold) {
      break; // Reached the knowledge threshold
    }
  }

  return BusFactorDto(
    busFactor: busFactor,
    totalDevelopers: authorCommits.length,
    topContributors: contributors,
  );
}
