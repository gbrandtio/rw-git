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
  Stream<String> runStream(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) {
    throw UnimplementedError();
  }
}

void main() {
  late MockProcessRunner mockRunner;
  late CodeVolatilityAlgorithm algorithm;

  setUp(() {
    mockRunner = MockProcessRunner();
    algorithm = CodeVolatilityAlgorithm(mockRunner);
  });

  group('CodeVolatilityAlgorithm', () {
    test('calculates volatility correctly', () async {
      mockRunner.mockResult('git', [
        'log',
        '--name-only',
        '--format=AUTHOR:%an',
      ], 'AUTHOR:Alice\nfile1.dart\nfile2.dart\nAUTHOR:Bob\nfile1.dart\n');

      final results = await algorithm.execute('./test');

      expect(results.length, 2);
      final file1 = results.firstWhere((r) => r.filePath == 'file1.dart');
      expect(file1.uniqueAuthors, 2);
      expect(file1.totalChanges, 2);
      expect(file1.volatilityScore, 4.0); // 2 * 2
    });

    test('respects limit', () async {
      mockRunner.mockResult('git', [
        'log',
        '-n',
        '10',
        '--name-only',
        '--format=AUTHOR:%an',
      ], 'AUTHOR:Alice\nfile1.dart\n');

      final results = await algorithm.execute('./test', limit: '10');

      expect(results.length, 1);
    });

    test('handles empty git log', () async {
      mockRunner.mockResult('git', [
        'log',
        '--name-only',
        '--format=AUTHOR:%an',
      ], '');
      final results = await algorithm.execute('./test');
      expect(results, isEmpty);
    });

    test('forwards since/until as git flags', () async {
      mockRunner.mockResult('git', [
        'log',
        '--name-only',
        '--format=AUTHOR:%an',
        '--since=2024-01-01',
        '--until=2024-12-31',
      ], 'AUTHOR:Alice\nfile1.dart\n');
      final results = await algorithm.execute(
        './test',
        since: '2024-01-01',
        until: '2024-12-31',
      );
      expect(results.length, 1);
    });

    test('forwards revisionRange as a git argument', () async {
      mockRunner.mockResult('git', [
        'log',
        '--name-only',
        '--format=AUTHOR:%an',
        'origin/main..HEAD',
      ], 'AUTHOR:Alice\nfile1.dart\n');
      final results = await algorithm.execute(
        './test',
        revisionRange: 'origin/main..HEAD',
      );
      expect(results.length, 1);
    });

    test('forwards targetFiles as pathspecs', () async {
      mockRunner.mockResult('git', [
        'log',
        '--name-only',
        '--format=AUTHOR:%an',
        '--',
        'file1.dart',
        'file2.dart',
      ], 'AUTHOR:Alice\nfile1.dart\n');
      final results = await algorithm.execute(
        './test',
        targetFiles: ['file1.dart', 'file2.dart'],
      );
      expect(results.length, 1);
    });
  });
}
