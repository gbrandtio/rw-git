import 'package:rw_git/src/core/process_runner.dart';
import 'package:rw_git/src/models/churn_metrics_dto.dart';
import 'package:rw_git/src/models/churn_metrics_with_authors_dto.dart';

/// ----------------------------------------------------------------------------
/// churn_heuristic.dart
/// ----------------------------------------------------------------------------
class ChurnHeuristic {
  final ProcessRunner runner;

  ChurnHeuristic(this.runner);

  Future<ChurnMetricsDto> calculateChurn(String directory,
      {String? limit, String? since, String? until}) async {
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
    final commitCountResult =
        await runner.run('git', countArgs, workingDirectory: directory);
    evaluateProcessResult(commitCountResult);
    final totalCommits =
        int.tryParse(commitCountResult.stdout?.toString().trim() ?? '0') ?? 0;

    final logArgs = ['log', '-p', '--format='];
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

    final stream =
        runner.runStream('git', logArgs, workingDirectory: directory);

    final Map<String, int> fileChurn = {};
    final Map<String, int> classChurn = {};
    final Map<String, int> blockChurn = {};

    await for (final line in stream) {
      if (line.trim().isEmpty) continue;

      if (line.startsWith('--- a/')) {
        final fileName = line.substring(6).trim();
        if (fileName != '/dev/null') {
          fileChurn[fileName] = (fileChurn[fileName] ?? 0) + 1;
        }
      } else if (line.startsWith('@@ ')) {
        final parts = line.split('@@');
        if (parts.length >= 3) {
          final context = parts.sublist(2).join('@@').trim();
          if (context.isNotEmpty) {
            blockChurn[context] = (blockChurn[context] ?? 0) + 1;

            if (context.startsWith('class ')) {
              final className =
                  context.split(' ')[1].replaceAll('{', '').trim();
              if (className.isNotEmpty) {
                classChurn[className] = (classChurn[className] ?? 0) + 1;
              }
            }
          }
        }
      }
    }

    return ChurnMetricsDto(
      fileChurn: fileChurn,
      classChurn: classChurn,
      blockChurn: blockChurn,
      totalCommits: totalCommits,
    );
  }

  Future<ChurnMetricsWithAuthorsDto> calculateChurnWithAuthors(String directory,
      {String? limit, String? since, String? until}) async {
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
    final commitCountResult =
        await runner.run('git', countArgs, workingDirectory: directory);
    evaluateProcessResult(commitCountResult);
    final totalCommits =
        int.tryParse(commitCountResult.stdout?.toString().trim() ?? '0') ?? 0;

    final logArgs = ['log', '-p', '--format=AUTHOR:%an'];
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

    final stream =
        runner.runStream('git', logArgs, workingDirectory: directory);

    final Map<String, Map<String, int>> fileChurn = {};
    final Map<String, Map<String, int>> classChurn = {};
    final Map<String, Map<String, int>> blockChurn = {};

    String currentAuthor = 'Unknown';

    await for (final line in stream) {
      if (line.trim().isEmpty) continue;

      if (line.startsWith('AUTHOR:')) {
        currentAuthor = line.substring(7).trim();
      } else if (line.startsWith('--- a/')) {
        final fileName = line.substring(6).trim();
        if (fileName != '/dev/null') {
          fileChurn.putIfAbsent(fileName, () => {});
          fileChurn[fileName]![currentAuthor] =
              (fileChurn[fileName]![currentAuthor] ?? 0) + 1;
        }
      } else if (line.startsWith('@@ ')) {
        final parts = line.split('@@');
        if (parts.length >= 3) {
          final context = parts.sublist(2).join('@@').trim();
          if (context.isNotEmpty) {
            blockChurn.putIfAbsent(context, () => {});
            blockChurn[context]![currentAuthor] =
                (blockChurn[context]![currentAuthor] ?? 0) + 1;

            if (context.startsWith('class ')) {
              final className =
                  context.split(' ')[1].replaceAll('{', '').trim();
              if (className.isNotEmpty) {
                classChurn.putIfAbsent(className, () => {});
                classChurn[className]![currentAuthor] =
                    (classChurn[className]![currentAuthor] ?? 0) + 1;
              }
            }
          }
        }
      }
    }

    Map<String, ContributionStats> toStats(Map<String, Map<String, int>> map) {
      final result = <String, ContributionStats>{};
      for (final entry in map.entries) {
        final total = entry.value.values.fold<int>(0, (sum, val) => sum + val);
        result[entry.key] =
            ContributionStats(total: total, authors: entry.value);
      }
      return result;
    }

    return ChurnMetricsWithAuthorsDto(
      fileChurn: toStats(fileChurn),
      classChurn: toStats(classChurn),
      blockChurn: toStats(blockChurn),
      totalCommits: totalCommits,
    );
  }
}
