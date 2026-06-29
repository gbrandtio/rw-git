import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:rw_git/src/quality/logical_coupling_algorithm.dart';
import 'package:rw_git/src/quality/bus_factor_algorithm.dart';
import 'package:rw_git/src/quality/code_volatility_algorithm.dart';
import 'package:rw_git/src/quality/refactoring_detection_algorithm.dart';
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

  setUp(() {
    mockRunner = MockProcessRunner();
  });

  group('LogicalCouplingAlgorithm', () {
    test('detects files that frequently change together', () async {
      final algo = LogicalCouplingAlgorithm(mockRunner);
      final mockOutput = '''
COMMIT:123
fileA.dart
fileB.dart
COMMIT:456
fileA.dart
fileB.dart
fileC.dart
COMMIT:789
fileA.dart
fileB.dart
''';
      mockRunner.mockResult(
          'git',
          ['log', '-n', '500', '--name-only', '--format=COMMIT:%H'],
          mockOutput);

      final results = await algo.execute('.', limit: '500', minCoChanges: 2);

      expect(results.length, 1);
      expect(results[0].fileA, 'fileA.dart');
      expect(results[0].fileB, 'fileB.dart');
      expect(results[0].coChangeCount, 3);
      expect(results[0].confidence,
          1.0); // 100% confidence since they always change together
    });
  });

  group('BusFactorAlgorithm', () {
    test('calculates correct bus factor and top contributors', () async {
      final algo = BusFactorAlgorithm(mockRunner);
      final mockOutput = '''
Alice
Alice
Alice
Bob
Charlie
Alice
''';
      // Total 6 commits. Alice: 4 (66%), Bob: 1, Charlie: 1.
      mockRunner.mockResult(
          'git', ['log', '-n', '500', '--format=%an'], mockOutput);

      final result =
          await algo.execute('.', limit: '500', knowledgeThreshold: 0.50);

      expect(result.busFactor, 1);
      expect(result.totalDevelopers, 3);
      expect(result.topContributors.first.author, 'Alice');
      expect(result.topContributors.first.contributions, 4);
    });
  });

  group('CodeVolatilityAlgorithm', () {
    test('calculates volatility based on churn and unique authors', () async {
      final algo = CodeVolatilityAlgorithm(mockRunner);
      final mockOutput = '''
AUTHOR:Alice
fileA.dart
fileB.dart
AUTHOR:Bob
fileA.dart
AUTHOR:Charlie
fileA.dart
''';
      // fileA: 3 changes, 3 unique authors -> score 9
      // fileB: 1 change, 1 unique author -> score 1
      mockRunner.mockResult(
          'git',
          ['log', '-n', '500', '--name-only', '--format=AUTHOR:%an'],
          mockOutput);

      final results = await algo.execute('.', limit: '500');

      expect(results.length, 2);
      expect(results[0].filePath, 'fileA.dart');
      expect(results[0].volatilityScore, 9.0);
      expect(results[0].uniqueAuthors, 3);
      expect(results[1].filePath, 'fileB.dart');
      expect(results[1].volatilityScore, 1.0);
    });
  });

  group('RefactoringDetectionAlgorithm', () {
    test('detects renames and explicit refactoring commits', () async {
      final algo = RefactoringDetectionAlgorithm(mockRunner);
      final mockOutput = '''
COMMIT||hash1||Alice||2023-01-01T00:00:00Z||refactor: reorganize packages
 3 files changed, 100 insertions(+), 50 deletions(-)
COMMIT||hash2||Bob||2023-01-02T00:00:00Z||feat: new stuff
R100	old_file.dart	new_file.dart
 2 files changed, 10 insertions(+), 10 deletions(-)
COMMIT||hash3||Alice||2023-01-03T00:00:00Z||cleanup dead code
 5 files changed, 2 insertions(+), 200 deletions(-)
''';
      mockRunner.mockResult(
          'git',
          [
            'log',
            '-n',
            '500',
            '-M',
            '--name-status',
            '--shortstat',
            '--format=COMMIT||%H||%an||%aI||%s'
          ],
          mockOutput);

      final results = await algo.execute('.', limit: '500');

      expect(results.length, 3);

      // Hash1: Message matches "refactor"
      expect(results[0].commitHash, 'hash1');
      expect(results[0].isSimplification, false);

      // Hash2: Contains a rename
      expect(results[1].commitHash, 'hash2');
      expect(results[1].renamedFiles.length, 1);
      expect(results[1].renamedFiles[0], 'old_file.dart -> new_file.dart');

      // Hash3: Simplification (deleted 200, inserted 2)
      expect(results[2].commitHash, 'hash3');
      expect(results[2].isSimplification, true);
    });
  });
}
