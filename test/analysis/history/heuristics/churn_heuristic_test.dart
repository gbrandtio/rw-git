import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

class MockProcessRunner implements ProcessRunner {
  List<String>? lastRunArgs;
  List<String>? lastStreamArgs;
  List<String> streamLines = const [];

  @override
  Future<ProcessResult> run(
    String ex,
    List<String> arg, {
    String? workingDirectory,
    bool streamOutput = false,
  }) async {
    lastRunArgs = arg;
    return ProcessResult(0, 0, '0', '');
  }

  @override
  Stream<String> runStream(
    String ex,
    List<String> arg, {
    String? workingDirectory,
  }) async* {
    lastStreamArgs = arg;
    for (final line in streamLines) {
      yield line;
    }
  }
}

void main() {
  group('ChurnHeuristic', () {
    test('calculateChurn forwards since/until as git flags on both count '
        'and log calls', () async {
      final runner = MockProcessRunner();
      await ChurnHeuristic(
        runner,
      ).calculateChurn('./test', since: '2024-01-01', until: '2024-12-31');
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
        runner.lastStreamArgs!.any((a) => a.startsWith('--until=')),
        isFalse,
      );
    });

    test('calculateChurnWithAuthors forwards since/until as git flags on both '
        'count and log calls', () async {
      final runner = MockProcessRunner();
      await ChurnHeuristic(runner).calculateChurnWithAuthors(
        './test',
        since: '2024-01-01',
        until: '2024-12-31',
      );
      expect(runner.lastRunArgs, contains('--since=2024-01-01'));
      expect(runner.lastRunArgs, contains('--until=2024-12-31'));
      expect(runner.lastStreamArgs, contains('--since=2024-01-01'));
      expect(runner.lastStreamArgs, contains('--until=2024-12-31'));
    });

    test('calculateChurn forwards revisionRange as a git argument', () async {
      final runner = MockProcessRunner();
      await ChurnHeuristic(
        runner,
      ).calculateChurn('./test', revisionRange: 'origin/main..HEAD');
      expect(runner.lastRunArgs, contains('origin/main..HEAD'));
      expect(runner.lastRunArgs, isNot(contains('HEAD')));
      expect(runner.lastStreamArgs, contains('origin/main..HEAD'));
    });

    test(
      'calculateChurnWithAuthors forwards revisionRange as a git argument',
      () async {
        final runner = MockProcessRunner();
        await ChurnHeuristic(runner).calculateChurnWithAuthors(
          './test',
          revisionRange: 'origin/main..HEAD',
        );
        expect(runner.lastRunArgs, contains('origin/main..HEAD'));
        expect(runner.lastRunArgs, isNot(contains('HEAD')));
        expect(runner.lastStreamArgs, contains('origin/main..HEAD'));
      },
    );

    test('calculateChurn forwards targetFiles as pathspecs', () async {
      final runner = MockProcessRunner();
      await ChurnHeuristic(
        runner,
      ).calculateChurn('./test', targetFiles: ['a.dart', 'b.dart']);
      expect(runner.lastStreamArgs, contains('--'));
      expect(runner.lastStreamArgs, containsAll(['a.dart', 'b.dart']));
    });

    test('calculateChurn excludes files outside targetFiles even when a '
        'matching commit touched them too (git pathspec only filters '
        'commits, not each commit\'s --name-only file list)', () async {
      final runner = MockProcessRunner()
        ..streamLines = ['a.dart', 'unrelated.dart'];
      final result = await ChurnHeuristic(
        runner,
      ).calculateChurn('./test', targetFiles: ['a.dart']);
      expect(result.fileChurn.keys, ['a.dart']);
    });

    test('calculateChurnWithAuthors excludes files outside targetFiles even '
        'when a matching commit touched them too', () async {
      final runner = MockProcessRunner()
        ..streamLines = ['AUTHOR:Alice', 'a.dart', 'unrelated.dart'];
      final result = await ChurnHeuristic(
        runner,
      ).calculateChurnWithAuthors('./test', targetFiles: ['a.dart']);
      expect(result.fileChurn.keys, ['a.dart']);
    });
  });
}
