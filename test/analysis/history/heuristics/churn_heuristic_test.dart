import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

class MockProcessRunner implements ProcessRunner {
  List<String>? lastRunArgs;
  List<String>? lastStreamArgs;

  @override
  Future<ProcessResult> run(String ex, List<String> arg,
      {String? workingDirectory, bool streamOutput = false}) async {
    lastRunArgs = arg;
    return ProcessResult(0, 0, '0', '');
  }

  @override
  Stream<String> runStream(String ex, List<String> arg,
      {String? workingDirectory}) async* {
    lastStreamArgs = arg;
  }
}

void main() {
  group('ChurnHeuristic', () {
    test(
        'calculateChurn forwards since/until as git flags on both count '
        'and log calls', () async {
      final runner = MockProcessRunner();
      await ChurnHeuristic(runner)
          .calculateChurn('./test', since: '2024-01-01', until: '2024-12-31');
      expect(runner.lastRunArgs, contains('--since=2024-01-01'));
      expect(runner.lastRunArgs, contains('--until=2024-12-31'));
      expect(runner.lastStreamArgs, contains('--since=2024-01-01'));
      expect(runner.lastStreamArgs, contains('--until=2024-12-31'));
    });

    test('calculateChurn omits since/until flags when not provided', () async {
      final runner = MockProcessRunner();
      await ChurnHeuristic(runner).calculateChurn('./test');
      expect(runner.lastRunArgs!.any((a) => a.startsWith('--since=')), isFalse);
      expect(
          runner.lastStreamArgs!.any((a) => a.startsWith('--until=')), isFalse);
    });

    test(
        'calculateChurnWithAuthors forwards since/until as git flags on both '
        'count and log calls', () async {
      final runner = MockProcessRunner();
      await ChurnHeuristic(runner).calculateChurnWithAuthors('./test',
          since: '2024-01-01', until: '2024-12-31');
      expect(runner.lastRunArgs, contains('--since=2024-01-01'));
      expect(runner.lastRunArgs, contains('--until=2024-12-31'));
      expect(runner.lastStreamArgs, contains('--since=2024-01-01'));
      expect(runner.lastStreamArgs, contains('--until=2024-12-31'));
    });
  });
}
