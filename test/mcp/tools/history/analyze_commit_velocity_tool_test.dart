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
      final tool = AnalyzeCommitVelocityTool(runner);

      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema.isNotEmpty, isTrue);
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
      final tool = AnalyzeCommitVelocityTool(runner);

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
      final tool = AnalyzeCommitVelocityTool(runner);

      final result = await tool.execute({'directory': '/test'});

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
      final tool = AnalyzeCommitVelocityTool(runner);

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
      final tool = AnalyzeCommitVelocityTool(runner);

      final result = await tool.execute({
        'directory': '/test',
        'granularity': 'month',
        'since': '2024-01-01',
        'until': '2024-12-31',
      });

      final parsed = jsonDecode(result) as Map<String, dynamic>;
      final series = parsed['time_series'] as List;
      expect(series.length, 2);
    });

    test('detects accelerating trend and burnout', () async {
      final log = [
        'aaa||Alice||2024-01-01T04:00:00+00:00', // burnout
        'bbb||Alice||2024-01-08T10:00:00+00:00',
        'ccc||Alice||2024-01-15T10:00:00+00:00',
        'ddd||Alice||2024-01-16T10:00:00+00:00',
        'eee||Alice||2024-01-22T10:00:00+00:00',
        'fff||Alice||2024-01-23T10:00:00+00:00',
        'ggg||Alice||2024-01-24T10:00:00+00:00', // high velocity in week 4
      ].join('\n');

      final runner = _MockRunner(log);
      final tool = AnalyzeCommitVelocityTool(runner);

      final result = await tool.execute({
        'directory': '/test',
        'granularity': 'week',
      });
      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['trend'], 'accelerating');
    });

    test(
      'classifies burnout using the author\'s own UTC offset, not raw UTC',
      () async {
        final log = [
          // 22:00 local (author's own +08:00 offset) -> burnout.
          // The same instant is 14:00 UTC, which would NOT be burnout under a
          // naive UTC-hour comparison. Asserting burnout_commits == 1 proves
          // classification uses authorLocal, not raw UTC.
          'aaa||Alice||2024-01-01T22:00:00+08:00',
        ].join('\n');

        final runner = _MockRunner(log);
        final tool = AnalyzeCommitVelocityTool(runner);

        final result = await tool.execute({
          'directory': '/test',
          'granularity': 'week',
        });
        final parsed = jsonDecode(result) as Map<String, dynamic>;

        expect(parsed['total_burnout_commits'], 1);
        final series = parsed['time_series'] as List;
        expect(series.length, 1);
        expect((series.first as Map)['burnout_commits'], 1);
      },
    );

    test('detects decelerating trend', () async {
      final log = [
        'aaa||Alice||2024-01-01T10:00:00+00:00',
        'bbb||Alice||2024-01-02T10:00:00+00:00',
        'ccc||Alice||2024-01-03T10:00:00+00:00',
        'ddd||Alice||2024-01-08T10:00:00+00:00',
        'eee||Alice||2024-01-09T10:00:00+00:00',
        'fff||Alice||2024-01-15T10:00:00+00:00', // drop in velocity
        'ggg||Alice||2024-01-22T10:00:00+00:00',
      ].join('\n');

      final runner = _MockRunner(log);
      final tool = AnalyzeCommitVelocityTool(runner);

      final result = await tool.execute({
        'directory': '/test',
        'granularity': 'week',
      });
      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['trend'], 'decelerating');
    });

    test('rejects invalid since date', () async {
      final runner = _MockRunner('');
      final tool = AnalyzeCommitVelocityTool(runner);

      final result = await tool.execute({
        'directory': '/test',
        'since': 'not-a-date',
      });
      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['error'], contains('"since"'));
    });

    test('rejects invalid until date', () async {
      final runner = _MockRunner('');
      final tool = AnalyzeCommitVelocityTool(runner);

      final result = await tool.execute({
        'directory': '/test',
        'until': 'some random garbage',
      });
      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['error'], contains('"until"'));
    });

    test('accepts valid ISO-8601 since and until dates', () async {
      final log = [
        'aaa||Alice||2024-01-15T10:00:00+00:00',
        'bbb||Bob||2024-02-15T10:00:00+00:00',
      ].join('\n');

      final runner = _MockRunner(log);
      final tool = AnalyzeCommitVelocityTool(runner);

      final result = await tool.execute({
        'directory': '/test',
        'since': '2024-01-01',
        'until': '2024-12-31',
      });
      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed.containsKey('error'), isFalse);
    });

    test('accepts relative git date phrases', () async {
      final runner = _MockRunner('');
      final tool = AnalyzeCommitVelocityTool(runner);

      final result = await tool.execute({
        'directory': '/test',
        'since': '2 weeks ago',
      });
      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed.containsKey('error'), isFalse);
    });

    test('returns gini_coefficient and velocity_slope', () async {
      final log = [
        'aaa||Alice||2024-01-01T10:00:00+00:00',
        'bbb||Alice||2024-01-08T10:00:00+00:00',
        'ccc||Bob||2024-01-15T10:00:00+00:00',
      ].join('\n');

      final runner = _MockRunner(log);
      final tool = AnalyzeCommitVelocityTool(runner);

      final result = await tool.execute({
        'directory': '/test',
        'granularity': 'week',
      });
      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed.containsKey('gini_coefficient'), isTrue);
      expect(parsed.containsKey('velocity_slope'), isTrue);
      expect(parsed['gini_coefficient'], isA<double>());
      expect(parsed['velocity_slope'], isA<double>());
    });

    test('gini_coefficient is 0.0 when only one author', () async {
      final log = [
        'aaa||Alice||2024-01-01T10:00:00+00:00',
        'bbb||Alice||2024-01-08T10:00:00+00:00',
      ].join('\n');

      final runner = _MockRunner(log);
      final tool = AnalyzeCommitVelocityTool(runner);

      final result = await tool.execute({'directory': '/test'});
      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['gini_coefficient'], 0.0);
    });

    test('detects anomalies', () async {
      final log = [
        'aaa||Alice||2024-01-01T10:00:00+00:00', // week 1
        'bbb||Alice||2024-01-08T10:00:00+00:00', // week 2
        'ccc||Alice||2024-01-15T10:00:00+00:00', // week 3
        'ddd||Alice||2024-01-22T10:00:00+00:00', // week 4
        'eee||Alice||2024-01-29T10:00:00+00:00', // week 5
        'fff||Alice||2024-02-05T10:00:00+00:00', // week 6
        for (int i = 0; i < 20; i++)
          'ggg\$i||Alice||2024-02-12T10:00:00+00:00', // week 7 spike
      ].join('\n');

      final runner = _MockRunner(log);
      final tool = AnalyzeCommitVelocityTool(runner);

      final result = await tool.execute({
        'directory': '/test',
        'granularity': 'week',
      });
      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect((parsed['anomalies'] as List).isNotEmpty, isTrue);
    });
  });
}
