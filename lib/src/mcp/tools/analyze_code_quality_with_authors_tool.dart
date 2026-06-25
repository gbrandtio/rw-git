import '../../../rw_git.dart';

/// analyze_code_quality_with_authors_tool.dart
/// Analyzes a git repository for suspicious or massive commits, and calculates churn metrics
/// broken down by authors.

class AnalyzeCodeQualityWithAuthorsTool implements McpTool {
  final CodeQualityTracker tracker;
  final RwGit rwGit;

  AnalyzeCodeQualityWithAuthorsTool(this.tracker, this.rwGit);

  @override
  String get name => 'analyze_code_quality_with_authors';

  @override
  String get description =>
      "Analyzes the target git repository's commit history to surface architectural bottlenecks and technical debt. "
      'It identifies suspicious commits, detects mega-commits, and computes code churn metrics to highlight '
      'high-churn files, classes, and code blocks, along with a breakdown of which authors contributed to each. '
      'To invoke this tool, provide the `directory` (String) and an optional `limit` (Number, default: 10) for commits to review. '
      'For a complete guide on how to use the rw_git MCP tools, invoke the get_rw_git_documentation tool.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'directory': {
            'type': 'string',
            'description': 'The local repository path.'
          },
          'limit': {
            'type': 'number',
            'description':
                'Number of commits to retrieve for AI review (default: 10).'
          }
        },
        'required': ['directory']
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments['directory'] as String;
    final limit = arguments['limit']?.toString() ?? '10';

    final suspicious = await tracker.findSuspiciousCommits(directory);
    final mega = await tracker.findMegaCommits(directory);
    final churn = await tracker.calculateChurnWithAuthors(directory);

    // Calculate High Churn files (>10% of total commits)
    final highChurnThreshold = (churn.totalCommits * 0.10).ceil();
    final highChurnFiles = churn.fileChurn.entries
        .where((e) =>
            e.value.total >= highChurnThreshold && churn.totalCommits > 0)
        .toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));

    final commitsLog =
        await rwGit.runCommand(directory, ['log', '-n', limit, '-p']);

    return '''
You are a Staff Software Engineer. The task is to analyze, as per the instructions given below and provide a
report. The report must be structured as follows:
a. Executive summary section.
b. Code quality metrics section.
c. Conclusion.

In the report:
- You must include the total commits analyzed.
- You must include the total contributors, along with a score for quality based on the analyzed commits.
- For every commit that is present in the report, you MUST include: date of the commit, hash, 
commit message, author. DO NOT include only the hash.

Please analyze the following code quality metrics and recent git commits.
I want you to specifically check for:
1. Bad commit messages: look for frustrated, unhelpful, non-detailed, or low-effort messages (e.g., "fixed stuff", "updates", "todo", "fixme", "do not touch", "argh", "wip").
2. Commented-out code blocks left behind in the diff.
3. Too many changes with a vague or incomplete or inaccurate summary / commit message.
4. Architectural bottlenecks or technical debt highlighted in the quality metrics below (high churn files, mega commits).

Code Quality Metrics:
--------------------------------------------------
Suspicious Commits (fixme/todo/temporary):
${suspicious.isEmpty ? 'None found.' : suspicious.join('\n')}

Mega Commits (>500 lines changed or >20 files):
${mega.isEmpty ? 'None found.' : mega.join('\n')}

High Churn Files (modified in >10% of commits, total commits: ${churn.totalCommits}):
${highChurnFiles.isEmpty ? 'None found.' : highChurnFiles.map((e) => '- ${e.key}: ${e.value.total} changes\n${_formatAuthors(e.value.authors)}').join('\n')}

Top Churned Classes:
${_formatTop(churn.classChurn)}

Top Churned Blocks/Methods:
${_formatTop(churn.blockChurn)}
--------------------------------------------------

Commits to review:
--------------------------------------------------
$commitsLog
--------------------------------------------------
''';
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
