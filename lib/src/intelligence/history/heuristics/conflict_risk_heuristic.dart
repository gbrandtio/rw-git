import 'package:rw_git/src/core/process_runner.dart';

/// ----------------------------------------------------------------------------
/// conflict_risk_heuristic.dart
/// ----------------------------------------------------------------------------
class ConflictRiskHeuristic {
  final ProcessRunner runner;

  ConflictRiskHeuristic(this.runner);

  /// Identifies files modified on both branches since their
  /// merge base, predicting potential merge conflicts.
  Future<Map<String, List<String>>> findConflictRiskFiles(
      String directory, String branchA, String branchB) async {
    // Find the merge base between the two branches
    final mergeBaseResult = await runner.run(
      'git',
      ['merge-base', branchA, branchB],
      workingDirectory: directory,
    );
    evaluateProcessResult(mergeBaseResult);
    final mergeBase = mergeBaseResult.stdout?.toString().trim() ?? '';

    // Files changed on branchA since merge base
    final diffAResult = await runner.run(
      'git',
      ['diff', '--name-only', mergeBase, branchA],
      workingDirectory: directory,
    );
    evaluateProcessResult(diffAResult);
    final filesA = (diffAResult.stdout?.toString() ?? '')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    // Files changed on branchB since merge base
    final diffBResult = await runner.run(
      'git',
      ['diff', '--name-only', mergeBase, branchB],
      workingDirectory: directory,
    );
    evaluateProcessResult(diffBResult);
    final filesB = (diffBResult.stdout?.toString() ?? '')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    final setA = filesA.toSet();
    final setB = filesB.toSet();
    final both = setA.intersection(setB).toList();
    final onlyA = setA.difference(setB).toList();
    final onlyB = setB.difference(setA).toList();

    // Integrate git merge-tree for exact textual conflict detection
    final List<String> textualConflicts = [];
    try {
      final mergeTreeResult = await runner.run(
        'git',
        ['merge-tree', '--write-tree', branchA, branchB],
        workingDirectory: directory,
      );

      // merge-tree returns exit code 1 if there are conflicts, 0 if clean.
      // If it returns > 1, it might mean the command failed (e.g. old git version).
      if (mergeTreeResult.exitCode == 0 || mergeTreeResult.exitCode == 1) {
        final outLines = (mergeTreeResult.stdout?.toString() ?? '').split('\n');
        for (final line in outLines) {
          if (line.startsWith('CONFLICT') && line.contains(' in ')) {
            final parts = line.split(' in ');
            if (parts.length > 1) {
              textualConflicts.add(parts.last.trim());
            }
          }
        }
      }
    } catch (e) {
      // Fallback if git merge-tree --write-tree is not supported, just rely on 'both'
    }

    return {
      'merge_base': [mergeBase],
      'files_only_on_a': onlyA,
      'files_only_on_b': onlyB,
      'conflicting_files': both, // logical overlaps
      'textual_conflicting_files': textualConflicts, // exact text conflicts
    };
  }
}
