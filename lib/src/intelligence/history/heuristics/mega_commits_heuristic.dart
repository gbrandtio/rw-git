import 'dart:isolate';
import 'package:rw_git/src/core/process_runner.dart';

/// ----------------------------------------------------------------------------
/// mega_commits_heuristic.dart
/// ----------------------------------------------------------------------------
class MegaCommitsHeuristic {
  final ProcessRunner runner;

  MegaCommitsHeuristic(this.runner);

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
}

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
