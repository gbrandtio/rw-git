import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

class MockProcessRunner implements ProcessRunner {
  final Map<String, String> _mocks = {};

  void mockResult(String executable, List<String> arguments, String stdout) {
    _mocks['$executable ${arguments.join(' ')}'] = stdout;
  }

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool streamOutput = false,
  }) async {
    final cmd = '$executable ${arguments.join(' ')}';
    if (_mocks.containsKey(cmd)) {
      return ProcessResult(0, 0, _mocks[cmd], '');
    }
    return ProcessResult(0, 0, '', '');
  }

  @override
  Stream<String> runStream(String executable, List<String> arguments,
      {String? workingDirectory}) {
    throw UnimplementedError();
  }
}

void main() {
  late MockProcessRunner mockRunner;
  late RefactoringDetectionAlgorithm algorithm;

  setUp(() {
    mockRunner = MockProcessRunner();
    algorithm = RefactoringDetectionAlgorithm(mockRunner);
  });

  group('RefactoringDetectionAlgorithm', () {
    test('detects refactoring correctly', () async {
      mockRunner.mockResult(
          'git',
          [
            'log',
            '-n',
            '100',
            '-M',
            '--name-status',
            '--shortstat',
            '--format=COMMIT||%H||%an||%aI||%s'
          ],
          'COMMIT||hash123||Alice||2023-01-01T00:00:00Z||refactor: cleanup code\n 2 files changed, 100 insertions(+), 50 deletions(-)\n');

      final results = await algorithm.execute('./test', limit: '100');

      expect(results.length, 1);
      expect(results[0].commitHash, 'hash123');
      expect(results[0].renamedFiles.length, 0);
    });

    test('handles empty git log', () async {
      mockRunner.mockResult(
          'git',
          [
            'log',
            '-n',
            '100',
            '-M',
            '--name-status',
            '--shortstat',
            '--format=COMMIT||%H||%an||%aI||%s'
          ],
          '');
      final results = await algorithm.execute('./test', limit: '100');
      expect(results, isEmpty);
    });
  });
}
