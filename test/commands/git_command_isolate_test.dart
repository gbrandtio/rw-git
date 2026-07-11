import 'dart:io';
import 'package:test/test.dart';
import 'package:rw_git/src/core/process_runner.dart';
import 'package:rw_git/src/commands/blame_command.dart';
import 'package:rw_git/src/commands/diff_command.dart';
import 'package:rw_git/src/commands/get_commits_command.dart';
import 'package:rw_git/src/commands/status_command.dart';

class _MockRunner implements ProcessRunner {
  final String output;

  _MockRunner(this.output);

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool streamOutput = false,
  }) async {
    return ProcessResult(0, 0, output, '');
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
  group('Command Isolate Coverage', () {
    final longOutput = List.generate(20000, (i) => 'a').join('');

    test('BlameCommand isolate', () async {
      // Valid blame lines long enough (>10000 chars) to trigger the isolate
      // path; parseBlame now throws on malformed lines, so arbitrary filler
      // no longer works here.
      final longBlameOutput = List.generate(
        200,
        (i) =>
            '1234abcd (Author 2021-01-01 00:00:00 +0000 ${i + 1}) some line content',
      ).join('\n');
      final runner = _MockRunner(longBlameOutput);
      final cmd = BlameCommand(runner);
      final res = await cmd.run('/test');
      expect(res.lines.length, 200);
    });

    test('DiffCommand isolate', () async {
      final runner = _MockRunner(longOutput);
      final cmd = DiffCommand(runner);
      final res = await cmd.run('/test');
      expect(res, isNotNull);
    });

    test('GetCommitsCommand isolate', () async {
      final runner = _MockRunner(longOutput);
      final cmd = GetCommitsCommand(runner, firstTag: "v1", secondTag: "v2");
      final res = await cmd.run('/test');
      expect(res, isNotNull);
    });

    test('StatusCommand isolate', () async {
      final runner = _MockRunner(longOutput);
      final cmd = StatusCommand(runner);
      final res = await cmd.run('/test');
      expect(res, isNotNull);
    });
  });
}
