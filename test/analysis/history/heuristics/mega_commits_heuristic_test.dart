import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

class MockProcessRunner implements ProcessRunner {
  final Map<String, String> _mocks = {};

  void mockResult(String executable, List<String> arguments, String stdout) {
    _mocks['$executable ${arguments.join(' ')}'] = stdout;
  }

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool streamOutput = false,
  }) async {
    final cmd = '$executable ${arguments.join(' ')}';
    if (_mocks.containsKey(cmd)) {
      return ProcessResult(0, 0, _mocks[cmd], '');
    }
    return ProcessResult(0, 0, '', '');
  }

  @override
  Stream<String> runStream(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) {
    throw UnimplementedError();
  }
}

void main() {
  late MockProcessRunner mockRunner;
  late MegaCommitsHeuristic heuristic;

  setUp(() {
    mockRunner = MockProcessRunner();
    heuristic = MegaCommitsHeuristic(mockRunner);
  });

  group('MegaCommitsHeuristic', () {
    test('detects mega commits', () async {
      mockRunner.mockResult(
        'git',
        ['log', '--shortstat', '--format=%H||%an||%aI||%s'],
        'hash1||Alice||2023-01-01T12:00:00Z||msg1\n 25 files changed, 500 insertions(+), 50 deletions(-)\n',
      );

      final results = await heuristic.findMegaCommits(
        './test',
        lineThreshold: 100,
      );

      expect(results.length, 1);
      expect(results[0].contains('hash1'), isTrue);
    });

    test('handles empty git log', () async {
      mockRunner.mockResult('git', [
        'log',
        '--shortstat',
        '--format=%H||%an||%aI||%s',
      ], '');
      final results = await heuristic.findMegaCommits(
        './test',
        lineThreshold: 100,
      );
      expect(results, isEmpty);
    });

    test('forwards since/until as git flags', () async {
      mockRunner.mockResult('git', [
        'log',
        '--shortstat',
        '--format=%H||%an||%aI||%s',
        '--since=2024-01-01',
        '--until=2024-12-31',
      ], '');
      final results = await heuristic.findMegaCommits(
        './test',
        lineThreshold: 100,
        since: '2024-01-01',
        until: '2024-12-31',
      );
      expect(results, isEmpty);
    });
  });
}
