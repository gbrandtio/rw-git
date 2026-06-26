import 'base_analyze_code_quality_tool.dart';

/// analyze_code_quality_tool.dart
/// Analyzes a git repository for suspicious or massive commits.

class AnalyzeCodeQualityTool extends BaseAnalyzeCodeQualityTool {
  AnalyzeCodeQualityTool(super.tracker, super.rwGit);

  @override
  String get name => 'analyze_code_quality';

  @override
  String get description =>
      "Analyzes the target git repository's commit history to surface architectural bottlenecks and technical debt. "
      'It identifies suspicious commits containing keywords like "fixme" or "todo", detects mega-commits '
      '(commits touching > 20 files or > 500 lines of code), and computes code churn metrics to highlight '
      'high-churn files modified in >10% of all commits, along with the most frequently modified classes and code blocks. '
      'To invoke this tool, provide the `directory` (String) and an optional `limit` (Number, default: 10) for commits to review. '
      'You can also provide `includeRawLog` (Boolean, default: false) to append the raw git log to the response, '
      'and `topN` (Number, default: null) to restrict the lists to the top N entries. '
      'For a complete guide on how to use the rw_git MCP tools, invoke the get_rw_git_documentation tool.';

  @override
  String getPromptInstructions() {
    return '''
- You must include the total commits analyzed.
- For every commit that is present in the report, you MUST include: date of the commit, hash, 
commit message. DO NOT include only the hash.''';
  }

  @override
  Future<String> getChurnMetricsString(
      String directory, String limit, int? topN) async {
    final churn = await tracker.calculateChurn(directory, limit: limit);

    // Calculate High Churn files (>10% of total commits)
    final highChurnThreshold = (churn.totalCommits * 0.10).ceil();
    var highChurnFiles = churn.fileChurn.entries
        .where((e) => e.value >= highChurnThreshold && churn.totalCommits > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (topN != null) {
      if (highChurnFiles.length > topN) {
        highChurnFiles = highChurnFiles.take(topN).toList();
      }
    }

    return '''
High Churn Files (modified in >10% of commits, total commits: ${churn.totalCommits}):
${highChurnFiles.isEmpty ? 'None found.' : highChurnFiles.map((e) => '- ${e.key}: ${e.value} changes').join('\n')}

Top Churned Classes:
${_formatTop(churn.classChurn, top: topN ?? 5)}

Top Churned Blocks/Methods:
${_formatTop(churn.blockChurn, top: topN ?? 5)}''';
  }

  String _formatTop(Map<String, int> data, {int top = 5}) {
    if (data.isEmpty) return 'None found.';
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted
        .take(top)
        .map((e) => '- ${e.key}: ${e.value} changes')
        .join('\n');
  }
}
