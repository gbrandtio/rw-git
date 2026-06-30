import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

class MockProcessRunner implements ProcessRunner {
  @override
  Future<ProcessResult> run(String ex, List<String> arg,
      {String? workingDirectory, bool streamOutput = false}) async {
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
}
