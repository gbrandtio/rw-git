import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

class MockProcessRunner implements ProcessRunner {
  List<String>? lastArgs;

  @override
  Future<ProcessResult> run(String ex, List<String> arg,
      {String? workingDirectory, bool streamOutput = false}) async {
    lastArgs = arg;
    return ProcessResult(0, 0, 'Alice\nBob\nCharlie\n', '');
  }

  @override
  Stream<String> runStream(String ex, List<String> arg,
          {String? workingDirectory}) =>
      throw UnimplementedError();
}

void main() {
  test('BusFactorAlgorithm calculates bus factor correctly', () async {
    final res = await BusFactorAlgorithm(MockProcessRunner()).execute('./');
    expect(res.totalDevelopers, 3);
  });

  test('BusFactorAlgorithm forwards since/until as git flags', () async {
    final runner = MockProcessRunner();
    await BusFactorAlgorithm(runner)
        .execute('./', since: '2024-01-01', until: '2024-12-31');
    expect(runner.lastArgs, contains('--since=2024-01-01'));
    expect(runner.lastArgs, contains('--until=2024-12-31'));
  });

  test('BusFactorAlgorithm omits since/until flags when not provided',
      () async {
    final runner = MockProcessRunner();
    await BusFactorAlgorithm(runner).execute('./');
    expect(runner.lastArgs!.any((a) => a.startsWith('--since=')), isFalse);
    expect(runner.lastArgs!.any((a) => a.startsWith('--until=')), isFalse);
  });
}
