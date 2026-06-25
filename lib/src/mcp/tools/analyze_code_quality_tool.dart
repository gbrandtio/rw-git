import '../../../rw_git.dart';

/// analyze_code_quality_tool.dart
/// Analyzes a git repository for suspicious or massive commits.

class AnalyzeCodeQualityTool implements McpTool {
  final CodeQualityTracker tracker;
  final RwGit rwGit;

  AnalyzeCodeQualityTool(this.tracker, this.rwGit);

  @override
  String get name => 'analyze_code_quality';

  @override
  String get description =>
      "Analyzes the target git repository's commit history to surface architectural bottlenecks and technical debt. "
      'It identifies suspicious commits containing keywords like "fixme" or "todo", detects mega-commits '
      '(commits touching > 20 files or > 500 lines of code), and computes code churn metrics to highlight '
      'high-churn files modified in >10% of all commits, along with the most frequently modified classes and code blocks. '
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
    final churn = await tracker.calculateChurn(directory);

    // Calculate High Churn files (>10% of total commits)
    final highChurnThreshold = (churn.totalCommits * 0.10).ceil();
    final highChurnFiles = churn.fileChurn.entries
        .where((e) => e.value >= highChurnThreshold && churn.totalCommits > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
- For every commit that is present in the report, you MUST include: date of the commit, hash, 
commit message. DO NOT include only the hash.

Please analyze/review the following code quality metrics and recent git commits.
I want you to specifically check for:
1. Bad commit messages: look for frustrated, unhelpful, non-detailed, or low-effort messages (e.g., "fixed stuff", "updates", "todo", "fixme", "do not touch", "argh", "wip").
2. Commented-out code blocks left behind in the diff.
3. Too many changes with a vague or incomplete or inaccurate summary / commit message.
4. Architectural bottlenecks or technical debt highlighted in the quality metrics below (high churn files, mega commits).
5. Code smells / bad code / code that doesn't follow best practices.

Code Quality Metrics:
--------------------------------------------------
Suspicious Commits (fixme/todo/temporary):
${suspicious.isEmpty ? 'None found.' : suspicious.join('\n')}

Mega Commits (>500 lines changed or >20 files):
${mega.isEmpty ? 'None found.' : mega.join('\n')}

High Churn Files (modified in >10% of commits, total commits: ${churn.totalCommits}):
${highChurnFiles.isEmpty ? 'None found.' : highChurnFiles.map((e) => '- ${e.key}: ${e.value} changes').join('\n')}

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
