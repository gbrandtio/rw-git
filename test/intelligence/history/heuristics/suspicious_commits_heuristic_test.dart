import 'dart:io';
import 'package:rw_git/src/core/process_runner.dart';
import 'package:rw_git/src/intelligence/history/heuristics/suspicious_commits_heuristic.dart';
import 'package:test/test.dart';

class _MockRunner implements ProcessRunner {
  final List<String> streamLines;
  final String runOutput;
  List<String>? lastRunArgs;
  List<String>? lastStreamArgs;

  _MockRunner({this.streamLines = const [], this.runOutput = ''});

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool streamOutput = false,
  }) async {
    lastRunArgs = arguments;
    return ProcessResult(0, 0, runOutput, '');
  }

  @override
  Stream<String> runStream(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async* {
    lastStreamArgs = arguments;
    for (final line in streamLines) {
      yield line;
    }
  }
}

void main() {
  group('SuspiciousCommitsHeuristic', () {
    test('findSuspiciousCommits identifies suspicious messages', () async {
      final runner = _MockRunner(streamLines: [
        'abcdef||Author Name||2023-01-01||this is a hack',
        '+++ b/lib/main.dart',
        '+ some code',
      ]);
      final heuristic = SuspiciousCommitsHeuristic(runner);
      final flagged = await heuristic.findSuspiciousCommits('/test');
      expect(flagged.length, 1);
      expect(flagged.first, contains('this is a hack'));
    });

    test('findSuspiciousCommits identifies suspicious code diffs', () async {
      final runner = _MockRunner(streamLines: [
        'abcdef||Author Name||2023-01-01||normal commit message',
        '+++ b/lib/main.dart',
        '+ // FIXME: this is broken',
      ]);
      final heuristic = SuspiciousCommitsHeuristic(runner);
      final flagged =
          await heuristic.findSuspiciousCommits('/test', limit: '10');
      expect(flagged.length, 1);
      expect(flagged.first, contains('normal commit message'));
    });

    test(
        'findSuspiciousCommits handles commit headers with < 4 parts and no date',
        () async {
      final runner = _MockRunner(streamLines: [
        'abcdef||just a hack without other info',
        '+++ b/lib/main.dart',
        '+ code',
      ]);
      final heuristic = SuspiciousCommitsHeuristic(runner);
      final flagged = await heuristic.findSuspiciousCommits('/test');
      expect(flagged.length, 1);
      expect(flagged.first, contains('just a hack without other info'));
    });

    test('findSuspiciousCommits handles diffs with incomplete header',
        () async {
      final runner = _MockRunner(streamLines: [
        'abcdef||normal message',
        '+++ b/lib/main.dart',
        '+ // temporary fix',
      ]);
      final heuristic = SuspiciousCommitsHeuristic(runner);
      final flagged = await heuristic.findSuspiciousCommits('/test');
      expect(flagged.length, 1);
      expect(flagged.first, contains('normal message'));
    });

    test('extractChangedComments parses comments from log', () async {
      final runOutput = '''abcdef||Author||2023-01-01||normal message
+++ b/lib/main.dart
@@ -1,3 +1,3 @@
+ // added a comment
+ int x = 1;
''';
      final runner = _MockRunner(runOutput: runOutput);
      final heuristic = SuspiciousCommitsHeuristic(runner);
      final comments = await heuristic.extractChangedComments('/test');
      expect(comments.length, 1);
      expect(comments.first['diff_block'], contains('added a comment'));
    });

    test('extractChangedComments parses comments with missing header info',
        () async {
      final runOutput = '''abcdef||normal message
+++ b/lib/main.dart
@@ -1,3 +1,3 @@
+ // added a comment
+ int x = 1;
''';
      final runner = _MockRunner(runOutput: runOutput);
      final heuristic = SuspiciousCommitsHeuristic(runner);
      final comments =
          await heuristic.extractChangedComments('/test', limit: '10');
      expect(comments.length, 1);
      expect(comments.first['commit'], 'abcdef||normal message');
    });

    test('extractChangedComments ignores non-comment blocks', () async {
      final runOutput = '''abcdef||Author||2023-01-01||normal message
+++ b/lib/main.dart
@@ -1,3 +1,3 @@
+ int x = 1;
''';
      final runner = _MockRunner(runOutput: runOutput);
      final heuristic = SuspiciousCommitsHeuristic(runner);
      final comments = await heuristic.extractChangedComments('/test');
      expect(comments.isEmpty, isTrue);
    });

    test('findSuspiciousCommits forwards since/until as git flags', () async {
      final runner = _MockRunner();
      final heuristic = SuspiciousCommitsHeuristic(runner);
      await heuristic.findSuspiciousCommits('/test',
          since: '2024-01-01', until: '2024-12-31');
      expect(runner.lastStreamArgs, contains('--since=2024-01-01'));
      expect(runner.lastStreamArgs, contains('--until=2024-12-31'));
    });

    test('extractChangedComments forwards since/until as git flags', () async {
      final runner = _MockRunner();
      final heuristic = SuspiciousCommitsHeuristic(runner);
      await heuristic.extractChangedComments('/test',
          since: '2024-01-01', until: '2024-12-31');
      expect(runner.lastRunArgs, contains('--since=2024-01-01'));
      expect(runner.lastRunArgs, contains('--until=2024-12-31'));
    });
  });
}
