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

  /// Analyzes the recent commits for suspicious keywords.
  Future<List<String>> findSuspiciousCommits(String directory) async {
    // Fetch recent commit logs
    final result = await runner.run('git', ['log', '--format=%H||%B'], workingDirectory: directory);
    evaluateProcessResult(result);
    
    final rawOutput = result.stdout?.toString() ?? '';
    
    // Offload parsing to an Isolate
    return await Isolate.run(() => _parseSuspiciousCommits(rawOutput));
  }
  
  /// Identifies mega-commits (e.g. ones that touch more than 500 lines or 20 files)
  Future<List<String>> findMegaCommits(String directory, {int lineThreshold = 500, int fileThreshold = 20}) async {
    final result = await runner.run('git', ['log', '--shortstat', '--format=%H'], workingDirectory: directory);
    evaluateProcessResult(result);
    
    final rawOutput = result.stdout?.toString() ?? '';
    
    // Offload parsing to an Isolate
    return await Isolate.run(() => _parseMegaCommits(rawOutput, lineThreshold, fileThreshold));
  }

  /// Calculates churn metrics (file, class, and block level churn frequencies).
  Future<ChurnMetricsDto> calculateChurn(String directory) async {
    final commitCountResult = await runner.run('git', ['rev-list', '--count', 'HEAD'], workingDirectory: directory);
    evaluateProcessResult(commitCountResult);
    final totalCommits = int.tryParse(commitCountResult.stdout?.toString().trim() ?? '0') ?? 0;

    final result = await runner.run('git', ['log', '-p', '--format='], workingDirectory: directory);
    evaluateProcessResult(result);

    final rawOutput = result.stdout?.toString() ?? '';

    // Offload parsing to an Isolate
    return await Isolate.run(() => _parseChurnMetrics(rawOutput, totalCommits));
  }

  /// Calculates churn metrics (file, class, and block level churn frequencies)
  /// and includes the authors who contributed to each.
  Future<ChurnMetricsWithAuthorsDto> calculateChurnWithAuthors(String directory) async {
    final commitCountResult = await runner.run('git', ['rev-list', '--count', 'HEAD'], workingDirectory: directory);
    evaluateProcessResult(commitCountResult);
    final totalCommits = int.tryParse(commitCountResult.stdout?.toString().trim() ?? '0') ?? 0;

    final result = await runner.run('git', ['log', '-p', '--format=AUTHOR:%an'], workingDirectory: directory);
    evaluateProcessResult(result);

    final rawOutput = result.stdout?.toString() ?? '';

    // Offload parsing to an Isolate
    return await Isolate.run(() => _parseChurnMetricsWithAuthors(rawOutput, totalCommits));
  }
}

// -----------------------------------------------------------------------------
// ISOLATE ENTRY POINTS (Must be static or top-level)
// -----------------------------------------------------------------------------

List<String> _parseSuspiciousCommits(String rawLog) {
  final List<String> flaggedCommits = [];
  final regex = RegExp(
      r'\b(fixme|fix me|to-do|todo|hack|workaround|kludge|temporary|temp|wip|do not touch|dont touch|magic|dirty|ugly|hotfix|quick fix|oops|wtf|password|passwd|secret|api_key|apikey|credentials|creds|bypass|backdoor)\b',
      caseSensitive: false
  );

  final lines = rawLog.split('\n');
  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final parts = line.split('||');
    if (parts.length >= 2) {
      final hash = parts[0];
      final message = parts.sublist(1).join('||');
      
      if (regex.hasMatch(message)) {
        flaggedCommits.add(hash);
      }
    }
  }
  
  return flaggedCommits;
}

List<String> _parseMegaCommits(String rawLog, int lineThreshold, int fileThreshold) {
  final List<String> flaggedCommits = [];
  
  final lines = rawLog.split('\n');
  String currentHash = '';
  
  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    
    // If line doesn't start with space, it's a commit hash
    if (!line.startsWith(' ')) {
      currentHash = line.trim();
    } else if (line.contains('changed') || line.contains('insertion') || line.contains('deletion')) {
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
        } else if (part.contains('file changed') || part.contains('files changed')) {
          filesChanged = int.tryParse(part.trim().split(' ')[0]) ?? 0;
        }
      }
      
      if (((insertions + deletions) >= lineThreshold || filesChanged >= fileThreshold) && currentHash.isNotEmpty) {
        flaggedCommits.add(currentHash);
      }
    }
  }
  return flaggedCommits;
}

ChurnMetricsDto _parseChurnMetrics(String rawLog, int totalCommits) {
  final Map<String, int> fileChurn = {};
  final Map<String, int> classChurn = {};
  final Map<String, int> blockChurn = {};

  final lines = rawLog.split('\n');

  for (final line in lines) {
    if (line.trim().isEmpty) continue;

    if (line.startsWith('--- a/')) {
      final fileName = line.substring(6).trim();
      if (fileName != '/dev/null') {
        fileChurn[fileName] = (fileChurn[fileName] ?? 0) + 1;
      }
    } else if (line.startsWith('@@ ')) {
      // Example line: @@ -10,5 +10,6 @@ class CodeQualityTracker {
      // We want to extract the context after the second '@@ '
      final parts = line.split('@@');
      if (parts.length >= 3) {
        final context = parts.sublist(2).join('@@').trim();
        if (context.isNotEmpty) {
          blockChurn[context] = (blockChurn[context] ?? 0) + 1;

          // A simple heuristic for class churn: check if context starts with 'class '
          if (context.startsWith('class ')) {
            final className = context.split(' ')[1].replaceAll('{', '').trim();
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

ChurnMetricsWithAuthorsDto _parseChurnMetricsWithAuthors(String rawLog, int totalCommits) {
  final Map<String, Map<String, int>> fileChurn = {};
  final Map<String, Map<String, int>> classChurn = {};
  final Map<String, Map<String, int>> blockChurn = {};

  final lines = rawLog.split('\n');
  String currentAuthor = 'Unknown';

  for (final line in lines) {
    if (line.trim().isEmpty) continue;

    if (line.startsWith('AUTHOR:')) {
      currentAuthor = line.substring(7).trim();
    } else if (line.startsWith('--- a/')) {
      final fileName = line.substring(6).trim();
      if (fileName != '/dev/null') {
        fileChurn.putIfAbsent(fileName, () => {});
        fileChurn[fileName]![currentAuthor] = (fileChurn[fileName]![currentAuthor] ?? 0) + 1;
      }
    } else if (line.startsWith('@@ ')) {
      final parts = line.split('@@');
      if (parts.length >= 3) {
        final context = parts.sublist(2).join('@@').trim();
        if (context.isNotEmpty) {
          blockChurn.putIfAbsent(context, () => {});
          blockChurn[context]![currentAuthor] = (blockChurn[context]![currentAuthor] ?? 0) + 1;

          if (context.startsWith('class ')) {
            final className = context.split(' ')[1].replaceAll('{', '').trim();
            if (className.isNotEmpty) {
              classChurn.putIfAbsent(className, () => {});
              classChurn[className]![currentAuthor] = (classChurn[className]![currentAuthor] ?? 0) + 1;
            }
          }
        }
      }
    }
  }

  // Convert the internal maps to ContributionStats
  Map<String, ContributionStats> toStats(Map<String, Map<String, int>> map) {
    final result = <String, ContributionStats>{};
    for (final entry in map.entries) {
      final total = entry.value.values.fold<int>(0, (sum, val) => sum + val);
      result[entry.key] = ContributionStats(total: total, authors: entry.value);
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
