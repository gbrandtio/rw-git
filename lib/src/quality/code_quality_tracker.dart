import 'dart:isolate';
import '../core/process_runner.dart';
import '../models/churn_metrics_dto.dart';
import '../models/churn_metrics_with_authors_dto.dart';

/// ----------------------------------------------------------------------------
/// code_quality_tracker.dart
/// ----------------------------------------------------------------------------
/// Evaluates git repositories for low quality code based on various heuristics:
/// - Mega commits
/// - Suspicious keywords (fixme, todo, etc.)
/// - Churn analysis
///
/// Uses Isolates to offload heavy string parsing and regex operations.

class CodeQualityTracker {
  final ProcessRunner runner;

  CodeQualityTracker(this.runner);

  /// Analyzes the commits for suspicious keywords by streaming the output
  /// and scanning both the commit message and added code in the diff.
  Future<List<String>> findSuspiciousCommits(String directory,
      {String? limit}) async {
    final args = ['log', '-p', '--format=%H||%an||%ad||%s'];
    if (limit != null) {
      args.insert(1, '-n');
      args.insert(2, limit);
    }

    final stream = runner.runStream('git', args, workingDirectory: directory);

    final List<String> flaggedCommits = [];
    final regex = RegExp(
        r'\b(fixme|fix me|to-do|todo|hack|workaround|kludge|temporary|temp|wip|do not touch|dont touch|magic|dirty|ugly|hotfix|quick fix|oops|wtf|password|passwd|secret|api_key|apikey|credentials|creds|bypass|backdoor)\b',
        caseSensitive: false);

    String currentCommitHeader = '';
    bool currentCommitFlagged = false;

    await for (final line in stream) {
      if (line.trim().isEmpty) continue;

      if (line.contains('||') &&
          !line.startsWith('+') &&
          !line.startsWith('-')) {
        // This is likely a commit header: %H||%an||%ad||%s
        final parts = line.split('||');
        if (parts.length >= 2) {
          currentCommitHeader = line;
          currentCommitFlagged = false; // Reset for new commit

          // Check if message itself has suspicious keywords
          final message = parts.sublist(parts.length >= 4 ? 3 : 1).join('||');
          if (regex.hasMatch(message)) {
            currentCommitFlagged = true;
            if (parts.length >= 4) {
              flaggedCommits
                  .add('${parts[0]} - ${parts[1]} (${parts[2]}): $message');
            } else {
              flaggedCommits.add('${parts[0]} - $message');
            }
          }
        }
      } else if (!currentCommitFlagged &&
          line.startsWith('+') &&
          !line.startsWith('+++ b/')) {
        // This is an added line in the diff
        if (regex.hasMatch(line)) {
          currentCommitFlagged = true;
          // Format using the stored header
          final parts = currentCommitHeader.split('||');
          if (parts.length >= 4) {
            final message = parts.sublist(3).join('||');
            flaggedCommits
                .add('${parts[0]} - ${parts[1]} (${parts[2]}): $message');
          } else if (parts.length >= 2) {
            final message = parts.sublist(1).join('||');
            flaggedCommits.add('${parts[0]} - $message');
          }
        }
      }
    }

    return flaggedCommits;
  }

  /// Identifies mega-commits (e.g. ones that touch more than 500 lines or 20 files)
  Future<List<String>> findMegaCommits(String directory,
      {int lineThreshold = 500, int fileThreshold = 20, String? limit}) async {
    final args = ['log', '--shortstat', '--format=%H||%an||%ad||%s'];
    if (limit != null) {
      args.insert(1, '-n');
      args.insert(2, limit);
    }
    final result = await runner.run('git', args, workingDirectory: directory);
    evaluateProcessResult(result);

    final rawOutput = result.stdout?.toString() ?? '';

    // Offload parsing to an Isolate
    return await Isolate.run(
        () => _parseMegaCommits(rawOutput, lineThreshold, fileThreshold));
  }

  Future<ChurnMetricsDto> calculateChurn(String directory,
      {String? limit}) async {
    final countArgs = ['rev-list', '--count'];
    if (limit != null) {
      countArgs.add('-n');
      countArgs.add(limit);
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

  /// Extracts added or modified comments from the diff, along with context.
  Future<String> extractChangedComments(String directory,
      {String? limit}) async {
    final logArgs = ['log', '-p', '--format=%H||%an||%ad||%s'];
    if (limit != null) {
      logArgs.insert(1, '-n');
      logArgs.insert(2, limit);
    }
    final result =
        await runner.run('git', logArgs, workingDirectory: directory);
    evaluateProcessResult(result);

    final rawOutput = result.stdout?.toString() ?? '';

    // Offload parsing to an Isolate
    return await Isolate.run(() => _parseChangedComments(rawOutput));
  }

  Future<ChurnMetricsWithAuthorsDto> calculateChurnWithAuthors(String directory,
      {String? limit}) async {
    final countArgs = ['rev-list', '--count'];
    if (limit != null) {
      countArgs.add('-n');
      countArgs.add(limit);
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

// -----------------------------------------------------------------------------
// ISOLATE ENTRY POINTS (Must be static or top-level)
// -----------------------------------------------------------------------------

List<String> _parseMegaCommits(
    String rawLog, int lineThreshold, int fileThreshold) {
  final List<String> flaggedCommits = [];

  final lines = rawLog.split('\n');
  String currentHashInfo = '';

  for (final line in lines) {
    if (line.trim().isEmpty) continue;

    // If line doesn't start with space, it's a commit hash info
    if (!line.startsWith(' ')) {
      currentHashInfo = line.trim();
    } else if (line.contains('changed') ||
        line.contains('insertion') ||
        line.contains('deletion')) {
      // Parse shortstat
      // Example: 3 files changed, 455 insertions(+), 12 deletions(-)
      int insertions = 0;
      int deletions = 0;
      int filesChanged = 0;

      final parts = line.split(',');
      for (final part in parts) {
        if (part.contains('insertion')) {
          insertions = int.tryParse(part.trim().split(' ')[0]) ?? 0;
        } else if (part.contains('deletion')) {
          deletions = int.tryParse(part.trim().split(' ')[0]) ?? 0;
        } else if (part.contains('file changed') ||
            part.contains('files changed')) {
          filesChanged = int.tryParse(part.trim().split(' ')[0]) ?? 0;
        }
      }

      if (((insertions + deletions) >= lineThreshold ||
              filesChanged >= fileThreshold) &&
          currentHashInfo.isNotEmpty) {
        final hashParts = currentHashInfo.split('||');
        if (hashParts.length >= 4) {
          final hash = hashParts[0];
          final author = hashParts[1];
          final date = hashParts[2];
          final message = hashParts.sublist(3).join('||');
          flaggedCommits.add('$hash - $author ($date): $message');
        } else {
          flaggedCommits.add(currentHashInfo);
        }
        currentHashInfo = '';
      }
    }
  }
  return flaggedCommits;
}

String _parseChangedComments(String rawLog) {
  final lines = rawLog.split('\n');
  final buffer = StringBuffer();

  String currentCommitHeader = '';
  String currentFile = '';
  List<String> currentBlock = [];
  bool blockHasComment = false;

  final commentRegex = RegExp(r'(?:\/\/|/\*|\*/|^\s*\*\s|#\s|<!--|--\s|^\s*#)');

  void flushBlock() {
    if (blockHasComment && currentBlock.isNotEmpty) {
      buffer.writeln('Commit: $currentCommitHeader');
      buffer.writeln('File: $currentFile');
      buffer.writeln(currentBlock.join('\n'));
      buffer.writeln('-' * 40);
    }
    currentBlock.clear();
    blockHasComment = false;
  }

  for (final line in lines) {
    if (line.trim().isEmpty) continue;

    if (line.contains('||') &&
        !line.startsWith(' ') &&
        !line.startsWith('+') &&
        !line.startsWith('-') &&
        !line.startsWith('@@') &&
        !line.startsWith('diff') &&
        !line.startsWith('index')) {
      flushBlock();
      final parts = line.split('||');
      if (parts.length >= 4) {
        currentCommitHeader =
            '${parts[0]} - ${parts[1]} (${parts[2]}): ${parts.sublist(3).join('||')}';
      } else {
        currentCommitHeader = line.trim();
      }
    } else if (line.startsWith('+++ b/')) {
      flushBlock();
      currentFile = line.substring(6).trim();
    } else if (line.startsWith('@@ ')) {
      flushBlock();
      currentBlock.add(line);
    } else if (currentBlock.isNotEmpty) {
      currentBlock.add(line);
      if (line.startsWith('+')) {
        final content = line.substring(1); // remove '+'
        if (commentRegex.hasMatch(content)) {
          blockHasComment = true;
        }
      }
    }
  }
  flushBlock();

  return buffer.toString().trim();
}
