import 'dart:convert';
import '../../../../rw_git.dart';
import '../../../constants.dart';
import '../../utils/date_range_validation.dart';
import '../../utils/mcp_argument_extensions.dart';

/// analyze_commit_velocity_tool.dart
/// Computes time-series commit velocity with trend
/// analysis and anomaly detection.

class AnalyzeCommitVelocityTool implements McpTool {
  final ProcessRunner runner;

  AnalyzeCommitVelocityTool(this.runner);

  @override
  String get name => 'analyze_commit_velocity';

  @override
  String get description =>
      'Computes commit velocity over time, bucketed by '
      'day, week, or month. Returns time-series data '
      'with per-author breakdown, trend analysis '
      '(accelerating/decelerating/stable), and anomaly '
      'detection (periods > 2 std deviations). '
      'For a complete guide, invoke the '
      'get_rw_git_documentation tool.';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'directory': {
        'type': 'string',
        'description': 'The local repository path.',
      },
      'limit': {
        'type': 'number',
        'description': 'Maximum number of commits to analyze.',
      },
      'since': {
        'type': 'string',
        'description':
            'Only commits after this date '
            '(e.g. "2024-01-01").',
      },
      'until': {
        'type': 'string',
        'description':
            'Only commits before this date '
            '(e.g. "2024-12-31").',
      },
      'granularity': {
        'type': 'string',
        'description':
            'Time bucket size: "day", "week", or '
            '"month". Defaults to "week".',
      },
    },
    'required': ['directory'],
  };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments.getStringArgument('directory');
    final limit = arguments['limit']?.toString() ?? defaultCommitLimit;
    final since = arguments.getOptionalStringArgument('since');
    final until = arguments.getOptionalStringArgument('until');
    final granularity =
        arguments.getOptionalStringArgument('granularity') ?? 'week';

    if (since != null && !isValidDateInput(since)) {
      return jsonEncode({
        'error':
            'Invalid "since" value. Use ISO-8601 (e.g. "2024-01-01") '
            'or a git relative date (e.g. "2 weeks ago").',
      });
    }
    if (until != null && !isValidDateInput(until)) {
      return jsonEncode({
        'error':
            'Invalid "until" value. Use ISO-8601 (e.g. "2024-12-31") '
            'or a git relative date (e.g. "1 month ago").',
      });
    }

    final velocity = await CommitVelocityHeuristic(runner)
        .calculateCommitVelocity(
          directory,
          limit: limit,
          since: since,
          until: until,
          granularity: granularity,
        );

    return jsonEncode({
      'total_commits': velocity.totalCommits,
      'average_per_period': double.parse(
        velocity.averagePerPeriod.toStringAsFixed(2),
      ),
      'trend': velocity.trend,
      'velocity_slope': velocity.velocitySlope,
      'gini_coefficient': velocity.giniCoefficient,
      'total_burnout_commits': velocity.totalBurnoutCommits,
      'granularity': granularity,
      'time_series': velocity.buckets
          .map(
            (b) => {
              'period': b.period,
              'total_commits': b.totalCommits,
              'burnout_commits': b.burnoutCommits,
              'authors': b.authors,
            },
          )
          .toList(),
      'anomalies': velocity.anomalies
          .map((b) => {'period': b.period, 'total_commits': b.totalCommits})
          .toList(),
    });
  }
}
