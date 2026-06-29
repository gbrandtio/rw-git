import 'base_analyze_code_quality_tool.dart';
import '../../constants.dart';

/// analyze_code_quality_with_authors_tool.dart
/// Analyzes a git repository for suspicious or massive
/// commits with author-level churn breakdown.
/// Returns structured JSON.

class AnalyzeCodeQualityWithAuthorsTool extends BaseAnalyzeCodeQualityTool {
  AnalyzeCodeQualityWithAuthorsTool(
    super.tracker,
    super.rwGit,
  );

  @override
  String get name => 'analyze_code_quality_with_authors';

  @override
  String get description => 'Analyzes commit history to surface architectural '
      'bottlenecks and technical debt with author-level '
      'breakdown. Returns structured JSON containing '
      'suspicious commits, mega-commits, and code churn '
      'metrics with per-author contribution counts. Set '
      '`includeCommitLog: true` for a compact commit log. '
      'For a complete guide, invoke the '
      'get_rw_git_documentation tool.';

  @override
  Map<String, dynamic> getAnalysisGuidance(bool includeCodeDiff) {
    final hints = [
      'Evaluate commit message quality against the '
          'change size shown in the metrics.',
      'Identify refactoring opportunities from '
          'high-churn files (potential SRP violations).',
      'Assess author concentration: files heavily '
          'modified by a single author may indicate '
          'knowledge silos.',
      'Flag commits with vague messages relative to '
          'their change magnitude.',
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
    final churn = await tracker.calculateChurnWithAuthors(
      directory,
      limit: limit,
    );

    final highChurnThreshold = (churn.totalCommits * 0.10).ceil();
    var highChurnFiles = churn.fileChurn.entries
        .where(
          (e) => e.value.total >= highChurnThreshold && churn.totalCommits > 0,
        )
        .toList()
      ..sort(
        (a, b) => b.value.total.compareTo(a.value.total),
      );

    final effectiveTopN = topN ?? defaultTopN;

    if (highChurnFiles.length > effectiveTopN) {
      highChurnFiles = highChurnFiles.take(effectiveTopN).toList();
    }

    final sortedClasses = churn.classChurn.entries.toList()
      ..sort(
        (a, b) => b.value.total.compareTo(a.value.total),
      );
    final sortedBlocks = churn.blockChurn.entries.toList()
      ..sort(
        (a, b) => b.value.total.compareTo(a.value.total),
      );

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
      'top_churned_classes': sortedClasses
          .take(effectiveTopN)
          .map(
            (e) => {
              'class': e.key,
              'changes': e.value.total,
              'authors': e.value.authors,
            },
          )
          .toList(),
      'top_churned_blocks': sortedBlocks
          .take(effectiveTopN)
          .map(
            (e) => {
              'block': e.key,
              'changes': e.value.total,
              'authors': e.value.authors,
            },
          )
          .toList(),
    };
  }
}
