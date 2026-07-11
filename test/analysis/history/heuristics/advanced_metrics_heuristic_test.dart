import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

class MockProcessRunner implements ProcessRunner {
  List<String>? lastArgs;

  @override
  Future<ProcessResult> run(
    String ex,
    List<String> arg, {
    String? workingDirectory,
    bool streamOutput = false,
  }) async {
    lastArgs = arg;
    return ProcessResult(
      0,
      0,
      'COMMIT:hash\n--- a/file1.dart\n+++ b/file1.dart\n@@ -10 +10 @@\n+ if (x) {}\n',
      '',
    );
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
}
