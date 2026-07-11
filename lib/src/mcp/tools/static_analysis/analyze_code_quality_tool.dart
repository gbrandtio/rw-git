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
      'Architecture Drift (commit distribution), '
      'file complexity, suspicious commits, and mega-commits. '
      'Set `includeAuthors: true` for per-author churn (knowledge silos), or '
      '`includeCommitLog: true` for a compact commit log. '
      'For a complete guide, invoke the get_rw_git_documentation tool.';

  @override
  Future<Map<String, dynamic>> getChurnData(
    String directory,
    String limit,
    int? topN, {
    bool includeAuthors = false,
  }) async {
    final effectiveTopN = topN ?? defaultTopN;

    if (!includeAuthors) {
      final churn = await ChurnHeuristic(
        runner,
      ).calculateChurn(directory, limit: limit);
      final highChurnThreshold = (churn.totalCommits * 0.10).ceil();
      var highChurnFiles = churn.fileChurn.entries
          .where(
            (e) => e.value >= highChurnThreshold && churn.totalCommits > 0,
          )
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (highChurnFiles.length > effectiveTopN) {
        highChurnFiles = highChurnFiles.take(effectiveTopN).toList();
      }

      return {
        'total_commits': churn.totalCommits,
        'high_churn_files': highChurnFiles
            .map((e) => {'file': e.key, 'changes': e.value})
            .toList(),
      };
    }

    final churn = await ChurnHeuristic(
      runner,
    ).calculateChurnWithAuthors(directory, limit: limit);
    final highChurnThreshold = (churn.totalCommits * 0.10).ceil();
    var highChurnFiles = churn.fileChurn.entries
        .where(
          (e) => e.value.total >= highChurnThreshold && churn.totalCommits > 0,
        )
        .toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));
    if (highChurnFiles.length > effectiveTopN) {
      highChurnFiles = highChurnFiles.take(effectiveTopN).toList();
    }

    return {
      'total_commits': churn.totalCommits,
      'high_churn_files': highChurnFiles
          .map(
            (e) => {
              'file': e.key,
              'changes': e.value.total,
              'authors': e.value.authors,
            },
          )
          .toList(),
    };
  }
}
