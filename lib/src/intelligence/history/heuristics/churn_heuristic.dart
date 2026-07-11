import 'package:rw_git/src/core/process_runner.dart';
import 'package:rw_git/src/models/churn_metrics_dto.dart';
import 'package:rw_git/src/models/churn_metrics_with_authors_dto.dart';

/// ----------------------------------------------------------------------------
/// churn_heuristic.dart
/// ----------------------------------------------------------------------------
class ChurnHeuristic {
  final ProcessRunner runner;

  ChurnHeuristic(this.runner);

  Future<ChurnMetricsDto> calculateChurn(
    String directory, {
    String? limit,
    String? since,
    String? until,
  }) async {
    final countArgs = ['rev-list', '--count'];
    if (limit != null) {
      countArgs.add('-n');
      countArgs.add(limit);
    }
    if (since != null) {
      countArgs.add('--since=$since');
    }
    if (until != null) {
      countArgs.add('--until=$until');
    }
    countArgs.add('HEAD');
    final commitCountResult = await runner.run(
      'git',
      countArgs,
      workingDirectory: directory,
    );
    evaluateProcessResult(commitCountResult);
    final totalCommits =
        int.tryParse(commitCountResult.stdout?.toString().trim() ?? '0') ?? 0;

    final logArgs = ['log', '--name-only', '--format='];
    if (limit != null) {
      logArgs.insert(1, '-n');
      logArgs.insert(2, limit);
    }
    if (since != null) {
      logArgs.add('--since=$since');
    }
    if (until != null) {
      logArgs.add('--until=$until');
    }

    final stream = runner.runStream(
      'git',
      logArgs,
      workingDirectory: directory,
    );

    final Map<String, int> fileChurn = {};

    await for (final line in stream) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      fileChurn[trimmedLine] = (fileChurn[trimmedLine] ?? 0) + 1;
    }

    return ChurnMetricsDto(fileChurn: fileChurn, totalCommits: totalCommits);
  }

  Future<ChurnMetricsWithAuthorsDto> calculateChurnWithAuthors(
    String directory, {
    String? limit,
    String? since,
    String? until,
  }) async {
    final countArgs = ['rev-list', '--count'];
    if (limit != null) {
      countArgs.add('-n');
      countArgs.add(limit);
    }
    if (since != null) {
      countArgs.add('--since=$since');
    }
    if (until != null) {
      countArgs.add('--until=$until');
    }
    countArgs.add('HEAD');
    final commitCountResult = await runner.run(
      'git',
      countArgs,
      workingDirectory: directory,
    );
    evaluateProcessResult(commitCountResult);
    final totalCommits =
        int.tryParse(commitCountResult.stdout?.toString().trim() ?? '0') ?? 0;

    final logArgs = ['log', '--name-only', '--format=AUTHOR:%an'];
    if (limit != null) {
      logArgs.insert(1, '-n');
      logArgs.insert(2, limit);
    }
    if (since != null) {
      logArgs.add('--since=$since');
    }
    if (until != null) {
      logArgs.add('--until=$until');
    }

    final stream = runner.runStream(
      'git',
      logArgs,
      workingDirectory: directory,
    );

    final Map<String, Map<String, int>> fileChurn = {};

    String currentAuthor = 'Unknown';

    await for (final line in stream) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      if (trimmedLine.startsWith('AUTHOR:')) {
        currentAuthor = trimmedLine.substring(7).trim();
      } else {
        fileChurn.putIfAbsent(trimmedLine, () => {});
        fileChurn[trimmedLine]![currentAuthor] =
            (fileChurn[trimmedLine]![currentAuthor] ?? 0) + 1;
      }
    }

    Map<String, ContributionStats> toStats(Map<String, Map<String, int>> map) {
      final result = <String, ContributionStats>{};
      for (final entry in map.entries) {
        final total = entry.value.values.fold<int>(0, (sum, val) => sum + val);
        result[entry.key] = ContributionStats(
          total: total,
          authors: entry.value,
        );
      }
      return result;
    }

    return ChurnMetricsWithAuthorsDto(
      fileChurn: toStats(fileChurn),
      totalCommits: totalCommits,
    );
  }
}
