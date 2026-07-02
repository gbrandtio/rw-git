import 'dart:isolate';
import 'package:rw_git/src/core/process_runner.dart';

/// ----------------------------------------------------------------------------
/// suspicious_commits_heuristic.dart
/// ----------------------------------------------------------------------------
/// Scans commits and code diffs for suspicious keywords, exposed issues, and
/// changed comments.
class SuspiciousCommitsHeuristic {
  final ProcessRunner runner;

  SuspiciousCommitsHeuristic(this.runner);

  /// Analyzes the commits for suspicious keywords by streaming the output
  /// and scanning both the commit message and added code in the diff.
  Future<List<String>> findSuspiciousCommits(String directory,
      {String? limit}) async {
    final args = ['log', '-p', '--format=%H||%an||%aI||%s'];
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
        // This is likely a commit header: %H||%an||%aI||%s
        final parts = line.split('||');
        if (parts.length >= 2) {
          currentCommitHeader = line;
          // Flag state is per-commit: without resetting here, a keyword match
          // in an earlier commit would incorrectly suppress detection for
          // every commit that follows it in the same log stream.
          currentCommitFlagged = false;

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

  /// Extracts added or modified comments from the diff, along with context.
  Future<List<Map<String, dynamic>>> extractChangedComments(String directory,
      {String? limit}) async {
    final logArgs = ['log', '-p', '--format=%H||%an||%aI||%s'];
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
}

List<Map<String, dynamic>> _parseChangedComments(String rawLog) {
  final lines = rawLog.split('\n');
  final List<Map<String, dynamic>> results = [];

  String currentCommitHeader = '';
  String currentCommitMessage = '';
  String currentFile = '';
  List<String> currentBlock = [];
  bool blockHasComment = false;

  final commentRegex = RegExp(r'(?:\/\/|/\*|\*/|^\s*\*\s|#\s|<!--|--\s|^\s*#)');

  // To exclude doc-only commits, check if message has keywords like docs, readme.
  final docOnlyRegex = RegExp(r'^(docs|readme|documentation|chore\(docs\)):?',
      caseSensitive: false);

  void flushBlock() {
    if (blockHasComment && currentBlock.isNotEmpty) {
      if (!docOnlyRegex.hasMatch(currentCommitMessage)) {
        // Find the index of the last comment line.
        // We will keep a few lines of context around it.
        // For simplicity, we just keep the whole block but formatted clearly.
        results.add({
          'commit': currentCommitHeader,
          'file': currentFile,
          'diff_block': currentBlock.join('\n'), // anchoring context
        });
      }
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
        currentCommitMessage = parts.sublist(3).join('||');
        currentCommitHeader =
            '${parts[0]} - ${parts[1]} (${parts[2]}): $currentCommitMessage';
      } else {
        currentCommitMessage = line.trim();
        currentCommitHeader = currentCommitMessage;
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
        // Diff-added lines are prefixed with '+' by `git log -p`; strip it
        // so the comment regex matches against the actual line content.
        final content = line.substring(1);
        if (commentRegex.hasMatch(content)) {
          blockHasComment = true;
        }
      }
    }
  }
  flushBlock();

  return results;
}
