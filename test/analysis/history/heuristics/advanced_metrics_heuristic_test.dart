import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

class MockProcessRunner implements ProcessRunner {
  MockProcessRunner([
    this.stdout =
        'COMMIT:hash\n--- a/file1.dart\n+++ b/file1.dart\n@@ -10 +10 @@\n+ if (x) {}\n',
  ]);

  final String stdout;
  List<String>? lastArgs;

  @override
  Future<ProcessResult> run(
    String ex,
    List<String> arg, {
    String? workingDirectory,
    bool streamOutput = false,
  }) async {
    lastArgs = arg;
    return ProcessResult(0, 0, stdout, '');
  }

  @override
  Stream<String> runStream(
    String ex,
    List<String> arg, {
    String? workingDirectory,
  }) => throw UnimplementedError();
}

void main() {
  test('AdvancedMetricsHeuristic calculates metrics correctly', () async {
    final res = await AdvancedMetricsHeuristic(
      MockProcessRunner(),
    ).calculateAdvancedMetrics('./');
    expect(res.fileComplexity.length, 1);
  });

  test('AdvancedMetricsHeuristic forwards since/until as git flags', () async {
    final runner = MockProcessRunner();
    await AdvancedMetricsHeuristic(
      runner,
    ).calculateAdvancedMetrics('./', since: '2024-01-01', until: '2024-12-31');
    expect(runner.lastArgs, contains('--since=2024-01-01'));
    expect(runner.lastArgs, contains('--until=2024-12-31'));
  });

  test(
    'attributes a newly added file to itself, not the previous file',
    () async {
      // One commit modifying old.dart, then adding new.dart. The added lines of
      // new.dart (pre-image /dev/null) must not be credited to old.dart.
      const log =
          'COMMIT:hash\n'
          '--- a/old.dart\n'
          '+++ b/old.dart\n'
          '@@ -1 +1 @@\n'
          '+ if (a) {}\n'
          '--- /dev/null\n'
          '+++ b/new.dart\n'
          '@@ -0 +1 @@\n'
          '+ while (b) {}\n'
          '+ for (;;) {}\n';
      final res = await AdvancedMetricsHeuristic(
        MockProcessRunner(log),
      ).calculateAdvancedMetrics('./');
      expect(res.fileComplexity['old.dart'], 1);
      expect(res.fileComplexity['new.dart'], 2);
    },
  );

  group('targetFiles', () {
    const log =
        'COMMIT:hash\n'
        '--- a/lib/a.dart\n'
        '+++ b/lib/a.dart\n'
        '@@ -1 +1 @@\n'
        '+ if (a) {}\n'
        '--- a/lib/b.dart\n'
        '+++ b/lib/b.dart\n'
        '@@ -1 +1 @@\n'
        '+ if (b) {}\n';

    test('forwards targetFiles as a git pathspec', () async {
      final runner = MockProcessRunner(log);
      await AdvancedMetricsHeuristic(
        runner,
      ).calculateAdvancedMetrics('./', targetFiles: ['lib/a.dart']);
      final args = runner.lastArgs!;
      expect(args.sublist(args.indexOf('--') + 1), ['lib/a.dart']);
    });

    test('restricts every reported metric to the target set', () async {
      final res = await AdvancedMetricsHeuristic(
        MockProcessRunner(log),
      ).calculateAdvancedMetrics('./', targetFiles: ['lib/a.dart']);
      expect(res.fileComplexity.keys, ['lib/a.dart']);
      expect(res.coChangeMatrix.keys, ['lib/a.dart']);
      expect(res.coChangeMatrix['lib/a.dart'], isEmpty);
    });

    test('keeps whole-repository behavior when omitted', () async {
      final res = await AdvancedMetricsHeuristic(
        MockProcessRunner(log),
      ).calculateAdvancedMetrics('./');
      expect(
        res.fileComplexity.keys,
        containsAll(['lib/a.dart', 'lib/b.dart']),
      );
      expect(res.coChangeMatrix['lib/a.dart']!['lib/b.dart'], 1);
    });
  });
}
