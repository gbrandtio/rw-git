import '../../../intelligence/history/heuristics/churn_heuristic.dart';
import 'base_analyze_code_quality_tool.dart';
import '../../../constants.dart';

/// analyze_code_quality_tool.dart
/// Analyzes a git repository for suspicious or massive commits and technical
/// debt. With `includeAuthors: true` it also breaks churn down per author.
/// Returns structured JSON.

class AnalyzeCodeQualityTool extends BaseAnalyzeCodeQualityTool {
  AnalyzeCodeQualityTool(super.runner, super.gitQuery);

  @override
  String get name => 'analyze_code_quality';

  @override
  String get description => 'Analyzes commit history to surface architectural '
      'bottlenecks and technical debt. Returns structured JSON containing '
      'advanced heuristics: Co-Change Matrix (SRP / Blast Radius), '
      'Method Churn (OCP violations), Architecture Drift (commit distribution), '
      'file complexity, suspicious commits, and mega-commits. '
      'Set `includeAuthors: true` for per-author churn (knowledge silos), or '
      '`includeCommitLog: true` for a compact commit log. '
      'For a complete guide, invoke the get_rw_git_documentation tool.';

  // Static, citation-backed guidance (SRP/OCP violation signals, mega-commit
  // thresholds, ownership bands) lives in toolHintsCatalog and is spliced in
  // by McpToolHintsDecorator. Only the argument-conditional hints below stay
  // here, emitted under the same `hints` shape so the decorator unions
  // rather than overwrites them.
  @override
  Map<String, dynamic> getAnalysisGuidance(bool includeCodeDiff,
      {bool includeAuthors = false}) {
    final interpretation = <String>[];
    if (includeAuthors) {
      interpretation.add(
        'Assess author concentration: files heavily modified by a single '
        'author (see the per-author breakdown) may indicate knowledge silos.',
      );
    }
    if (includeCodeDiff) {
      interpretation.add(
        'Review the code diffs for obvious code smells, '
        'anti-patterns, or technical debt introduced in '
        'the recent commits.',
      );
    }
    if (interpretation.isEmpty) return {};
    return {
      'hints': {'interpretation': interpretation},
    };
  }

  @override
  Future<Map<String, dynamic>> getChurnData(
    String directory,
    String limit,
    int? topN, {
    bool includeAuthors = false,
  }) async {
    final effectiveTopN = topN ?? defaultTopN;

    if (!includeAuthors) {
      final churn =
          await ChurnHeuristic(runner).calculateChurn(directory, limit: limit);
      final highChurnThreshold = (churn.totalCommits * 0.10).ceil();
      var highChurnFiles = churn.fileChurn.entries
          .where((e) => e.value >= highChurnThreshold && churn.totalCommits > 0)
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (highChurnFiles.length > effectiveTopN) {
        highChurnFiles = highChurnFiles.take(effectiveTopN).toList();
      }
      final sortedClasses = churn.classChurn.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final sortedBlocks = churn.blockChurn.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return {
        'total_commits': churn.totalCommits,
        'high_churn_files': highChurnFiles
            .map((e) => {'file': e.key, 'changes': e.value})
            .toList(),
        'top_churned_classes': sortedClasses
            .take(effectiveTopN)
            .map((e) => {'class': e.key, 'changes': e.value})
            .toList(),
        'top_churned_blocks': sortedBlocks
            .take(effectiveTopN)
            .map((e) => {'block': e.key, 'changes': e.value})
            .toList(),
      };
    }

    final churn = await ChurnHeuristic(runner)
        .calculateChurnWithAuthors(directory, limit: limit);
    final highChurnThreshold = (churn.totalCommits * 0.10).ceil();
    var highChurnFiles = churn.fileChurn.entries
        .where((e) =>
            e.value.total >= highChurnThreshold && churn.totalCommits > 0)
        .toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));
    if (highChurnFiles.length > effectiveTopN) {
      highChurnFiles = highChurnFiles.take(effectiveTopN).toList();
    }
    final sortedClasses = churn.classChurn.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));
    final sortedBlocks = churn.blockChurn.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));

    return {
      'total_commits': churn.totalCommits,
      'high_churn_files': highChurnFiles
          .map((e) => {
                'file': e.key,
                'changes': e.value.total,
                'authors': e.value.authors
              })
          .toList(),
      'top_churned_classes': sortedClasses
          .take(effectiveTopN)
          .map((e) => {
                'class': e.key,
                'changes': e.value.total,
                'authors': e.value.authors,
              })
          .toList(),
      'top_churned_blocks': sortedBlocks
          .take(effectiveTopN)
          .map((e) => {
                'block': e.key,
                'changes': e.value.total,
                'authors': e.value.authors,
              })
          .toList(),
    };
  }
}
