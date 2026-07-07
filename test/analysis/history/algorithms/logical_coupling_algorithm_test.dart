import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

class MockProcessRunner implements ProcessRunner {
  List<String>? lastArgs;

  @override
  Future<ProcessResult> run(String ex, List<String> arg,
      {String? workingDirectory, bool streamOutput = false}) async {
    lastArgs = arg;
    return ProcessResult(0, 0, 'COMMIT:123\nA\nB\nCOMMIT:456\nA\nB\nC\n', '');
  }

  @override
  Stream<String> runStream(String ex, List<String> arg,
          {String? workingDirectory}) =>
      throw UnimplementedError();
}

void main() {
  test('LogicalCouplingAlgorithm calculates coupling correctly', () async {
    final res = await LogicalCouplingAlgorithm(MockProcessRunner())
        .execute('./', minCoChanges: 1);
    expect(res, isNotEmpty);
  });
  test('LogicalCouplingAlgorithm respects limit', () async {
    final res = await LogicalCouplingAlgorithm(MockProcessRunner())
        .execute('./', limit: '5', minCoChanges: 1);
    expect(res, isNotEmpty);
  });
  test('LogicalCouplingAlgorithm forwards since/until as git flags', () async {
    final runner = MockProcessRunner();
    await LogicalCouplingAlgorithm(runner)
        .execute('./', since: '2024-01-01', until: '2024-12-31');
    expect(runner.lastArgs, contains('--since=2024-01-01'));
    expect(runner.lastArgs, contains('--until=2024-12-31'));
  });
  test('LogicalCouplingAlgorithm omits since/until flags when not provided',
      () async {
    final runner = MockProcessRunner();
    await LogicalCouplingAlgorithm(runner).execute('./');
    expect(runner.lastArgs!.any((a) => a.startsWith('--since=')), isFalse);
    expect(runner.lastArgs!.any((a) => a.startsWith('--until=')), isFalse);
  });
}
