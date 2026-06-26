import '../../../rw_git.dart';

/// base_analyze_code_quality_tool.dart
/// Abstract base class for code quality analysis tools using the Template Method pattern.

abstract class BaseAnalyzeCodeQualityTool implements McpTool {
  final CodeQualityTracker tracker;
  final RwGit rwGit;

  BaseAnalyzeCodeQualityTool(this.tracker, this.rwGit);

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
          },
          'includeRawLog': {
            'type': 'boolean',
            'description':
                'If true, appends the full raw git log output to the end of the prompt. (default: false)'
          },
          'topN': {
            'type': 'number',
            'description':
                'If provided, limits the size of the top lists (suspicious, mega, churned files, etc.) to N.'
          }
        },
        'required': ['directory']
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments['directory'] as String;
    final limit = arguments['limit']?.toString() ?? '10';
    final includeRawLog = arguments['includeRawLog'] as bool? ?? false;
    final topN = arguments['topN'] as int?;

    var suspicious =
        await tracker.findSuspiciousCommits(directory, limit: limit);
    var mega = await tracker.findMegaCommits(directory, limit: limit);

    if (topN != null) {
      if (suspicious.length > topN) {
        suspicious = suspicious.take(topN).toList();
      }
      if (mega.length > topN) {
        mega = mega.take(topN).toList();
      }
    }

    final churnMetricsString =
        await getChurnMetricsString(directory, limit, topN);
    final promptInstructions = getPromptInstructions();

    final commitsLog =
        (await rwGit.runCommand(directory, ['log', '-n', limit, '--stat']))
            .getOrThrow();

    return '''
You are a Staff Software Engineer. The task is to analyze, as per the instructions given below and provide a
report. The report must be structured as follows:
a. Executive summary section.
b. Code quality metrics section.
c. Conclusion.

In the report:
$promptInstructions

Please analyze/review the following code quality metrics and recent git commits.
I want you to specifically check for:
1. Bad commit messages: look for frustrated, unhelpful, non-detailed, or low-effort messages (e.g., "fixed stuff", "updates", "todo", "fixme", "do not touch", "argh", "wip").
2. Too many changes with a vague or incomplete or inaccurate summary / commit message (evaluate change size using the --stat output).
3. Architectural bottlenecks or technical debt highlighted in the quality metrics below (high churn files, mega commits, suspicious commits).
4. Code smells / bad code / code that doesn't follow best practices.

Code Quality Metrics:
--------------------------------------------------
Suspicious Commits (fixme/todo/temporary):
${suspicious.isEmpty ? 'None found.' : suspicious.join('\n')}

Mega Commits (>500 lines changed or >20 files):
${mega.isEmpty ? 'None found.' : mega.join('\n')}

$churnMetricsString
--------------------------------------------------
${includeRawLog ? '''
Commits to review:
--------------------------------------------------
$commitsLog
--------------------------------------------------
''' : ''}''';
  }

  /// Hook method to retrieve and format churn metrics.
  Future<String> getChurnMetricsString(
      String directory, String limit, int? topN);

  /// Hook method to retrieve specific prompt instructions for the tool.
  String getPromptInstructions();
}
