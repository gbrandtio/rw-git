import 'base_analyze_code_quality_tool.dart';

/// analyze_code_quality_tool.dart
/// Analyzes a git repository for suspicious or massive
/// commits. Returns structured JSON.

class AnalyzeCodeQualityTool extends BaseAnalyzeCodeQualityTool {
  AnalyzeCodeQualityTool(super.tracker, super.rwGit);

  @override
  String get name => 'analyze_code_quality';

  @override
  String get description => 'Analyzes commit history to surface architectural '
      'bottlenecks and technical debt. Returns structured JSON containing '
      'advanced heuristics: Co-Change Matrix (SRP / Blast Radius), '
      'Method Churn (OCP violations), Architecture Drift (commit distribution), '
      'file complexity, suspicious commits, and mega-commits. '
      'Set `includeCommitLog: true` for a compact commit log. '
      'For a complete guide, invoke the get_rw_git_documentation tool.';

  @override
  Map<String, dynamic> getAnalysisGuidance(bool includeCodeDiff) {
    final hints = [
      'Use the co_change_matrix to detect Single Responsibility Principle (SRP) violations. If a file frequently co-changes across multiple unrelated domains or features, it acts as a God Class.',
      'Use method_churn to detect Open/Closed Principle (OCP) violations. Methods modified in almost every branch violate OCP.',
      'Use the co_change_matrix to predict Blast Radius. If a PR modifies file A, check if file A historically co-changes with file B. If B is missing from the PR, flag it as a potential omission.',
      'Use architecture_distribution to track Architecture Drift. If recent commits heavily skew the historical distribution of commits across top-level directories, flag a potential architectural boundary violation.',
      'Use file_complexity to identify technical debt based on control flow keyword density.',
    ];
    if (includeCodeDiff) {
      hints.add(
        'Review the code diffs for obvious code smells, '
        'anti-patterns, or technical debt introduced in '
        'the recent commits.',
      );
    }
    return {
      'analysis_hints': hints,
    };
  }

  @override
  Future<Map<String, dynamic>> getChurnData(
    String directory,
    String limit,
    int? topN,
  ) async {
    final churn = await tracker.calculateChurn(
      directory,
      limit: limit,
    );

    final highChurnThreshold = (churn.totalCommits * 0.10).ceil();
    var highChurnFiles = churn.fileChurn.entries
        .where(
          (e) => e.value >= highChurnThreshold && churn.totalCommits > 0,
        )
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final effectiveTopN = topN ?? 5;

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
          .map(
            (e) => {'file': e.key, 'changes': e.value},
          )
          .toList(),
      'top_churned_classes': sortedClasses
          .take(effectiveTopN)
          .map(
            (e) => {'class': e.key, 'changes': e.value},
          )
          .toList(),
      'top_churned_blocks': sortedBlocks
          .take(effectiveTopN)
          .map(
            (e) => {'block': e.key, 'changes': e.value},
          )
          .toList(),
    };
  }
}
