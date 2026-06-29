import 'dart:convert';
import '../../../rw_git.dart';
import '../../constants.dart';
import '../utils/mcp_argument_extensions.dart';

/// base_analyze_code_quality_tool.dart
/// Abstract base class for code quality analysis tools
/// using the Template Method pattern.
///
/// Returns structured JSON instead of prose prompts,
/// aligning with `analyze_release_delta` and
/// `analyze_bus_factor` output conventions.

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
                'Number of commits to analyze (default: $defaultCommitLimit).'
          },
          'includeCommitLog': {
            'type': 'boolean',
            'description': 'If true, includes a compact commit log '
                '(hash, message, shortstat) in the response. '
                '(default: false)'
          },
          'includeCodeDiff': {
            'type': 'boolean',
            'description': 'If true, includes the actual code diffs '
                'for the recent commits, allowing the LLM to '
                'check for code smells. (default: false)'
          },
          'topN': {
            'type': 'number',
            'description': 'Limits all top-N lists (suspicious, mega, '
                'churn files, classes, blocks) to this '
                'many entries.'
          }
        },
        'required': ['directory']
      };

  @override
  Future<String> execute(
    Map<String, dynamic> arguments,
  ) async {
    final directory = arguments.getStringArgument('directory');
    final limit = arguments['limit']?.toString() ?? defaultCommitLimit;
    final includeCommitLog = arguments['includeCommitLog'] as bool? ?? false;
    final includeCodeDiff = arguments['includeCodeDiff'] as bool? ?? false;
    final topN = arguments['topN'] as int?;

    var suspicious = await tracker.findSuspiciousCommits(
      directory,
      limit: limit,
    );
    var mega = await tracker.findMegaCommits(
      directory,
      limit: limit,
    );

    if (topN != null) {
      if (suspicious.length > topN) {
        suspicious = suspicious.take(topN).toList();
      }
      if (mega.length > topN) {
        mega = mega.take(topN).toList();
      }
    }

    final churnData = await getChurnData(directory, limit, topN);
    final advancedMetrics =
        await tracker.calculateAdvancedMetrics(directory, limit: limit);

    final Map<String, dynamic> result = {
      'suspicious_commits': suspicious,
      'mega_commits': mega,
      ...churnData,
      'advanced_metrics': advancedMetrics.toJson(),
      ...getAnalysisGuidance(includeCodeDiff),
    };

    if (includeCommitLog) {
      final commitsLog = (await rwGit.runCommand(
        directory,
        [
          'log',
          '-n',
          limit,
          '--shortstat',
          '--format=%H %s',
        ],
      ))
          .getOrThrow();
      result['commit_log'] = commitsLog;
    }

    if (includeCodeDiff) {
      final codeDiff = (await rwGit.runCommand(
        directory,
        [
          'log',
          '-n',
          limit,
          '-p',
        ],
      ))
          .getOrThrow();
      result['code_diff'] = codeDiff;
    }

    return jsonEncode(result);
  }

  /// Hook method to retrieve and format churn metrics
  /// as a structured Map for JSON serialization.
  Future<Map<String, dynamic>> getChurnData(
    String directory,
    String limit,
    int? topN,
  );

  /// Hook method returning analysis guidance fields
  /// to include in the JSON response.
  Map<String, dynamic> getAnalysisGuidance(bool includeCodeDiff);
}
