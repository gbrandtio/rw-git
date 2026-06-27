// ignore_for_file: avoid_dynamic_calls
import 'dart:convert';
import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

class _MockRunner implements ProcessRunner {
  final String logOutput;

  _MockRunner(this.logOutput);

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool streamOutput = false,
  }) async {
    return ProcessResult(0, 0, logOutput, '');
  }

  @override
  Stream<String> runStream(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async* {}
}

void main() {
  group('AnalyzeCommitVelocityTool', () {
    test('has correct name and schema', () {
      final runner = _MockRunner('');
      final tracker = CodeQualityTracker(runner);
      final tool = AnalyzeCommitVelocityTool(tracker);

      expect(tool.name, 'analyze_commit_velocity');
      expect(tool.inputSchema['required'], contains('directory'));
    });

    test('returns time series data with trends', () async {
      final log = [
        'aaa||Alice||2024-01-01T10:00:00+00:00',
        'bbb||Alice||2024-01-02T10:00:00+00:00',
        'ccc||Bob||2024-01-08T10:00:00+00:00',
        'ddd||Alice||2024-01-15T10:00:00+00:00',
        'eee||Bob||2024-01-16T10:00:00+00:00',
      ].join('\n');

      final runner = _MockRunner(log);
      final tracker = CodeQualityTracker(runner);
      final tool = AnalyzeCommitVelocityTool(tracker);

      final result = await tool.execute({
        'directory': '/test',
        'granularity': 'week',
      });

      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['total_commits'], 5);
      expect(parsed['granularity'], 'week');
      expect(parsed.containsKey('time_series'), isTrue);
      expect(parsed.containsKey('trend'), isTrue);
      expect(parsed.containsKey('anomalies'), isTrue);

      final series = parsed['time_series'] as List;
      expect(series.isNotEmpty, isTrue);
    });

    test('handles empty log', () async {
      final runner = _MockRunner('');
      final tracker = CodeQualityTracker(runner);
      final tool = AnalyzeCommitVelocityTool(tracker);

      final result = await tool.execute({
        'directory': '/test',
      });

      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['total_commits'], 0);
      expect(parsed['trend'], 'stable');
    });

    test('supports day granularity', () async {
      final log = [
        'aaa||Alice||2024-01-01T10:00:00+00:00',
        'bbb||Bob||2024-01-01T11:00:00+00:00',
        'ccc||Alice||2024-01-02T10:00:00+00:00',
      ].join('\n');

      final runner = _MockRunner(log);
      final tracker = CodeQualityTracker(runner);
      final tool = AnalyzeCommitVelocityTool(tracker);

      final result = await tool.execute({
        'directory': '/test',
        'granularity': 'day',
      });

      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['granularity'], 'day');
      final series = parsed['time_series'] as List;
      expect(series.length, 2);
    });

    test('supports month granularity', () async {
      final log = [
        'aaa||Alice||2024-01-15T10:00:00+00:00',
        'bbb||Bob||2024-02-15T10:00:00+00:00',
      ].join('\n');

      final runner = _MockRunner(log);
      final tracker = CodeQualityTracker(runner);
      final tool = AnalyzeCommitVelocityTool(tracker);

      final result = await tool.execute({
        'directory': '/test',
        'granularity': 'month',
      });

      final parsed = jsonDecode(result) as Map<String, dynamic>;
      final series = parsed['time_series'] as List;
      expect(series.length, 2);
    });
  });
}
