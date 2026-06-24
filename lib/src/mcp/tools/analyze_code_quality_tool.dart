import '../../../rw_git.dart';

/// analyze_code_quality_tool.dart
/// Analyzes a git repository for suspicious or massive commits.

class AnalyzeCodeQualityTool implements McpTool {
  final CodeQualityTracker tracker;

  AnalyzeCodeQualityTool(this.tracker);

  @override
  String get name => 'analyze_code_quality';

  @override
  String get description =>
      "Analyzes the target git repository's commit history to surface architectural bottlenecks and technical debt. "
      'It identifies suspicious commits containing keywords like "fixme" or "todo", detects mega-commits '
      '(commits touching > 20 files or > 500 lines of code), and computes code churn metrics to highlight '
      'high-churn files modified in >10% of all commits, along with the most frequently modified classes and code blocks.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'directory': {
            'type': 'string',
            'description': 'The local repository path.'
          }
        },
        'required': ['directory']
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments['directory'] as String;

    final suspicious = await tracker.findSuspiciousCommits(directory);
    final mega = await tracker.findMegaCommits(directory);
    final churn = await tracker.calculateChurn(directory);

    // Calculate High Churn files (>10% of total commits)
    final highChurnThreshold = (churn.totalCommits * 0.10).ceil();
    final highChurnFiles = churn.fileChurn.entries
        .where((e) => e.value >= highChurnThreshold && churn.totalCommits > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return '''
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
''';
  }

  String _formatTop(Map<String, int> data, {int top = 5}) {
    if (data.isEmpty) return 'None found.';
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(top).map((e) => '- ${e.key}: ${e.value} changes').join('\n');
  }
}
