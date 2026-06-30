import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:rw_git/src/intelligence/history/heuristics/bug_hotspots_heuristic.dart';
import 'package:test/test.dart';

class MockProcessRunner implements ProcessRunner {
  @override
  Future<ProcessResult> run(String ex, List<String> arg,
      {String? workingDirectory, bool streamOutput = false}) async {
    final cmd = arg.join(' ');
    if (cmd.contains('--grep=')) {
      return ProcessResult(
          0,
          0,
          '0123456789012345678901234567890123456789\t2023-01-02T12:00:00Z\tfix\n',
          '');
    }
    if (cmd.contains('rev-parse')) {
      return ProcessResult(
          0, 0, '1111222233334444555566667777888899990000\n', '');
    }
    if (cmd.contains('diff -M')) {
      return ProcessResult(
          0,
          0,
          '--- a/file1.dart\n+++ b/file1.dart\n@@ -5 +5,0 @@\n- deleted_line_1\n',
          '');
    }
    if (cmd.contains('blame')) {
      return ProcessResult(
          0,
          0,
          'fedcba9876543210fedcba9876543210fedcba98 (Target 2023-01-01T12:00:00+00:00 5) deleted_line_1\n',
          '');
    }
    return ProcessResult(0, 0, '', '');
  }

  @override
  Stream<String> runStream(String ex, List<String> arg,
          {String? workingDirectory}) =>
      throw UnimplementedError();
}

void main() {
  test('BugHotspotsHeuristic calculates bug hotspots correctly', () async {
    final res = await BugHotspotsHeuristic(MockProcessRunner())
        .calculateBugHotspots('./');
    expect(res.fileHotspots, isNotEmpty);
  });
}
