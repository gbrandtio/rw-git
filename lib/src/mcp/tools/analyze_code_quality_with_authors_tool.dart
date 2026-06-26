import '../../../rw_git.dart';

import 'base_analyze_code_quality_tool.dart';

/// analyze_code_quality_with_authors_tool.dart
/// Analyzes a git repository for suspicious or massive commits, and calculates churn metrics
/// broken down by authors.

class AnalyzeCodeQualityWithAuthorsTool extends BaseAnalyzeCodeQualityTool {
  AnalyzeCodeQualityWithAuthorsTool(super.tracker, super.rwGit);

  @override
  String get name => 'analyze_code_quality_with_authors';

  @override
  String get description =>
      "Analyzes the target git repository's commit history to surface architectural bottlenecks and technical debt. "
      'It identifies suspicious commits, detects mega-commits, and computes code churn metrics to highlight '
      'high-churn files, classes, and code blocks, along with a breakdown of which authors contributed to each. '
      'To invoke this tool, provide the `directory` (String) and an optional `limit` (Number, default: 10) for commits to review. '
      'You can also provide `includeRawLog` (Boolean, default: false) to append the raw git log to the response, '
      'and `topN` (Number, default: null) to restrict the lists to the top N entries. '
      'For a complete guide on how to use the rw_git MCP tools, invoke the get_rw_git_documentation tool.';

  @override
  String getPromptInstructions() {
    return '''
- You must include the total commits analyzed.
- You must include the total contributors, along with a score for quality based on the analyzed commits.
- For every commit that is present in the report, you MUST include: date of the commit, hash, 
commit message, author. DO NOT include only the hash.''';
  }

  @override
  Future<String> getChurnMetricsString(
      String directory, String limit, int? topN) async {
    final churn =
        await tracker.calculateChurnWithAuthors(directory, limit: limit);

    // Calculate High Churn files (>10% of total commits)
    final highChurnThreshold = (churn.totalCommits * 0.10).ceil();
    var highChurnFiles = churn.fileChurn.entries
        .where((e) =>
            e.value.total >= highChurnThreshold && churn.totalCommits > 0)
        .toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));

    if (topN != null) {
      if (highChurnFiles.length > topN) {
        highChurnFiles = highChurnFiles.take(topN).toList();
      }
    }

    return '''
High Churn Files (modified in >10% of commits, total commits: ${churn.totalCommits}):
${highChurnFiles.isEmpty ? 'None found.' : highChurnFiles.map((e) => '- ${e.key}: ${e.value.total} changes\n${_formatAuthors(e.value.authors)}').join('\n')}

Top Churned Classes:
${_formatTop(churn.classChurn, top: topN ?? 5)}

Top Churned Blocks/Methods:
${_formatTop(churn.blockChurn, top: topN ?? 5)}''';
  }

  String _formatAuthors(Map<String, int> authors) {
    if (authors.isEmpty) return '    (No authors)';
    final sorted = authors.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => '    * ${e.key}: ${e.value}').join('\n');
  }

  String _formatTop(Map<String, ContributionStats> data, {int top = 5}) {
    if (data.isEmpty) return 'None found.';
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));
    return sorted
        .take(top)
        .map((e) =>
            '- ${e.key}: ${e.value.total} changes\n${_formatAuthors(e.value.authors)}')
        .join('\n');
  }
}
