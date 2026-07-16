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
        busFactor: 0,
        totalDevelopers: 0,
        topContributors: [],
      );
    }

    return await Isolate.run(
      () => _parseBusFactor(rawOutput, knowledgeThreshold),
    );
  }

  /// Executes the Bus Factor analysis for a specific list of files.
  ///
  /// Walks the history once (`git log --name-only -- <targetFiles>`) and
  /// splits the author counts per file, instead of spawning one git process
  /// per target file. Every file in [targetFiles] gets an entry; files
  /// without history in the window get an empty [BusFactorDto].
  ///
  /// [limit] bounds the single shared history walk (commits touching any
  /// target file), not each file's history individually.
  Future<Map<String, BusFactorDto>> executeForFiles(
    String directory,
    List<String> targetFiles, {
    String? limit,
    String? since,
    String? until,
    double knowledgeThreshold = 0.50, // 50% of contributions
  }) async {
    if (targetFiles.isEmpty) return {};

    final args = ['log', '--format=AUTHOR:%an', '--name-only'];
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
    args.add('--');
    args.addAll(targetFiles);

    final result = await runner.run('git', args, workingDirectory: directory);

    final rawOutput = result.exitCode == 0
        ? (result.stdout?.toString() ?? '')
        : '';
    if (rawOutput.isEmpty) {
      return {
        for (final file in targetFiles)
          file: BusFactorDto(
            busFactor: 0,
            totalDevelopers: 0,
            topContributors: [],
          ),
      };
    }

    final targets = List<String>.of(targetFiles);
    return await Isolate.run(
      () => _parsePerFileBusFactors(rawOutput, targets, knowledgeThreshold),
    );
  }
}

Map<String, BusFactorDto> _parsePerFileBusFactors(
  String rawLog,
  List<String> targetFiles,
  double threshold,
) {
  final targetSet = targetFiles.toSet();
  final perFileAuthorCommits = <String, Map<String, int>>{};
  String currentAuthor = 'Unknown';

  for (final line in rawLog.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    if (trimmed.startsWith('AUTHOR:')) {
      currentAuthor = trimmed.substring(7).trim();
    } else {
      // targetFiles is an exact result restriction, not just a commit
      // pre-filter (mirrors ChurnHeuristic's own targetFiles handling).
      if (!targetSet.contains(trimmed)) continue;
      final counts = perFileAuthorCommits.putIfAbsent(trimmed, () => {});
      counts[currentAuthor] = (counts[currentAuthor] ?? 0) + 1;
    }
  }

  return {
    for (final file in targetFiles)
      file: _busFactorFromCounts(
        perFileAuthorCommits[file] ?? const {},
        threshold,
      ),
  };
}

BusFactorDto _parseBusFactor(String rawLog, double threshold) {
  final lines = rawLog.split('\n');
  final Map<String, int> authorCommits = {};

  for (final line in lines) {
    final author = line.trim();
    if (author.isNotEmpty) {
      authorCommits[author] = (authorCommits[author] ?? 0) + 1;
    }
  }

  return _busFactorFromCounts(authorCommits, threshold);
}

BusFactorDto _busFactorFromCounts(
  Map<String, int> authorCommits,
  double threshold,
) {
  final totalCommits = authorCommits.values.fold<int>(0, (sum, v) => sum + v);

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

    contributors.add(
      DeveloperContribution(
        author: entry.key,
        contributions: entry.value,
        percentage: entry.value / totalCommits,
      ),
    );

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
