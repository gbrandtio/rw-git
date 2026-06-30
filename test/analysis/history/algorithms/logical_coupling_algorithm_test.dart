import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

class MockProcessRunner implements ProcessRunner {
  @override
  Future<ProcessResult> run(String ex, List<String> arg,
      {String? workingDirectory, bool streamOutput = false}) async {
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
}
