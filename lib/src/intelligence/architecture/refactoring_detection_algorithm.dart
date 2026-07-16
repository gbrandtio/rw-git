import 'dart:isolate';
import 'package:rw_git/src/core/process_runner.dart';
import 'package:rw_git/src/models/refactoring_dto.dart';

/// ----------------------------------------------------------------------------
/// refactoring_detection_algorithm.dart
/// ----------------------------------------------------------------------------
/// A lightweight heuristic-based algorithm inspired by RefactoringMiner.
/// Instead of full AST differencing (which is too heavy), it uses Git's native
/// rename detection (-M) and shortstat metrics to identify structural
/// refactorings and code simplifications.
class RefactoringDetectionAlgorithm {
  final ProcessRunner runner;

  RefactoringDetectionAlgorithm(this.runner);

  /// Executes the Refactoring Detection analysis.
  /// Uses an Isolate to process the `git log` output asynchronously.
  ///
  /// When [targetFiles] is provided, the history walk is limited to commits
  /// touching those paths (git pathspec) and reported renames are restricted
  /// to pairs whose old or new path is in [targetFiles]. Caveat: git can only
  /// pair a rename (`R` status) when the pathspec covers both of the rename's
  /// endpoints — a rename whose other endpoint falls outside [targetFiles]
  /// surfaces as an add/delete instead and goes undetected.
  Future<List<RefactoringDto>> execute(
    String directory, {
    String? limit,
    String? since,
    String? until,
    List<String>? targetFiles,
  }) async {
    // We need commits that are either explicitly marked as refactors,
    // OR contain file renames/moves.
    // Format: COMMIT||hash||author||date||message
    final args = [
      'log',
      '-M',
      '--name-status',
      '--shortstat',
      '--format=COMMIT||%H||%an||%aI||%s',
    ];
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
    if (targetFiles != null && targetFiles.isNotEmpty) {
      args.add('--');
      args.addAll(targetFiles);
    }

    final result = await runner.run('git', args, workingDirectory: directory);
    evaluateProcessResult(result);

    final rawOutput = result.stdout?.toString() ?? '';
    if (rawOutput.isEmpty) return [];

    // targetFiles is an exact result restriction, not just a commit
    // pre-filter (mirrors ChurnHeuristic's own targetFiles handling).
    final targetSet = (targetFiles != null && targetFiles.isNotEmpty)
        ? targetFiles.toSet()
        : null;

    return await Isolate.run(() => _parseRefactorings(rawOutput, targetSet));
  }
}

List<RefactoringDto> _parseRefactorings(
  String rawLog,
  Set<String>? targetFiles,
) {
  final lines = rawLog.split('\n');
  final results = <RefactoringDto>[];

  String hash = '';
  String author = '';
  String date = '';
  String message = '';
  List<String> renamedFiles = [];
  int inserted = 0;
  int deleted = 0;

  final refactorRegex = RegExp(
    r'\b(refactor|rewrite|restructure|clean|cleanup)\b',
    caseSensitive: false,
  );

  void flushCommit() {
    if (hash.isNotEmpty) {
      // Is it a refactoring?
      // Yes if: message contains refactoring keywords OR files were renamed
      bool isRefactor =
          refactorRegex.hasMatch(message) || renamedFiles.isNotEmpty;

      // A simplification refactoring is when we delete significantly more than we add
      // e.g., deleting 50+ lines and insertions are less than 20% of deletions
      bool isSimplification = deleted > 50 && (inserted < (deleted * 0.2));

      if (isRefactor || isSimplification) {
        results.add(
          RefactoringDto(
            commitHash: hash,
            author: author,
            date: date,
            message: message,
            renamedFiles: renamedFiles,
            linesInserted: inserted,
            linesDeleted: deleted,
            isSimplification: isSimplification,
          ),
        );
      }
    }

    // Reset
    hash = '';
    author = '';
    date = '';
    message = '';
    renamedFiles = [];
    inserted = 0;
    deleted = 0;
  }

  for (final line in lines) {
    if (line.trim().isEmpty) continue;

    if (line.startsWith('COMMIT||')) {
      flushCommit();
      final parts = line.split('||');
      if (parts.length >= 5) {
        hash = parts[1];
        author = parts[2];
        date = parts[3];
        message = parts.sublist(4).join('||');
      }
    } else if (line.startsWith('R') && line.contains('\t')) {
      // Rename detected: R100 old_name new_name
      final parts = line.split('\t');
      if (parts.length >= 3) {
        // Under targetFiles, only renames touching the target set are
        // reported (either endpoint qualifies).
        if (targetFiles == null ||
            targetFiles.contains(parts[1]) ||
            targetFiles.contains(parts[2])) {
          renamedFiles.add('${parts[1]} -> ${parts[2]}');
        }
      }
    } else if (line.contains(' changed') &&
        (line.contains(' insertion') || line.contains(' deletion'))) {
      // Parse shortstat: 3 files changed, 455 insertions(+), 12 deletions(-)
      final parts = line.split(',');
      for (final part in parts) {
        if (part.contains('insertion')) {
          inserted = int.tryParse(part.trim().split(' ')[0]) ?? 0;
        } else if (part.contains('deletion')) {
          deleted = int.tryParse(part.trim().split(' ')[0]) ?? 0;
        }
      }
    }
  }

  flushCommit(); // Final flush

  return results;
}
