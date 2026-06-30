import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

class MockProcessRunner implements ProcessRunner {
  @override
  Future<ProcessResult> run(String ex, List<String> arg,
      {String? workingDirectory, bool streamOutput = false}) async {
    return ProcessResult(
        0,
        0,
        'COMMIT:hash\n--- a/file1.dart\n+++ b/file1.dart\n@@ -10 +10 @@\n+ if (x) {}\n',
        '');
  }

  @override
  Stream<String> runStream(String ex, List<String> arg,
          {String? workingDirectory}) =>
      throw UnimplementedError();
}

void main() {
  test('AdvancedMetricsHeuristic calculates metrics correctly', () async {
    final res = await AdvancedMetricsHeuristic(MockProcessRunner())
        .calculateAdvancedMetrics('./');
    expect(res.fileComplexity.length, 1);
  });
}
