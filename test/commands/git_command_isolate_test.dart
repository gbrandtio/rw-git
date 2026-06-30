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
      final runner = _MockRunner(longOutput);
      final cmd = BlameCommand(runner);
      final res = await cmd.run('/test');
      expect(res, isNotNull);
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
