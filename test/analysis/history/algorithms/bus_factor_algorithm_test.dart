import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

class MockProcessRunner implements ProcessRunner {
  MockProcessRunner([this.stdout = 'Alice\nBob\nCharlie\n']);

  final String stdout;
  List<String>? lastArgs;
  int runCount = 0;

  @override
  Future<ProcessResult> run(
    String ex,
    List<String> arg, {
    String? workingDirectory,
    bool streamOutput = false,
  }) async {
    lastArgs = arg;
    runCount++;
    return ProcessResult(0, 0, stdout, '');
  }

  @override
  Stream<String> runStream(
    String ex,
    List<String> arg, {
    String? workingDirectory,
  }) => throw UnimplementedError();
}

void main() {
  test('BusFactorAlgorithm calculates bus factor correctly', () async {
    final res = await BusFactorAlgorithm(MockProcessRunner()).execute('./');
    expect(res.totalDevelopers, 3);
  });

  test('BusFactorAlgorithm forwards since/until as git flags', () async {
    final runner = MockProcessRunner();
    await BusFactorAlgorithm(
      runner,
    ).execute('./', since: '2024-01-01', until: '2024-12-31');
    expect(runner.lastArgs, contains('--since=2024-01-01'));
    expect(runner.lastArgs, contains('--until=2024-12-31'));
  });

  test(
    'BusFactorAlgorithm omits since/until flags when not provided',
    () async {
      final runner = MockProcessRunner();
      await BusFactorAlgorithm(runner).execute('./');
      expect(runner.lastArgs!.any((a) => a.startsWith('--since=')), isFalse);
      expect(runner.lastArgs!.any((a) => a.startsWith('--until=')), isFalse);
    },
  );

  group('executeForFiles', () {
    // git log --format=AUTHOR:%an --name-only output: two commits by Alice
    // touching a.dart (one also touching b.dart), one commit by Bob touching
    // b.dart and an out-of-target file.
    const nameOnlyLog =
        'AUTHOR:Alice\n\na.dart\nb.dart\n'
        'AUTHOR:Alice\n\na.dart\n'
        'AUTHOR:Bob\n\nb.dart\nother.dart\n';

    test('walks history once for all target files', () async {
      final runner = MockProcessRunner(nameOnlyLog);
      await BusFactorAlgorithm(
        runner,
      ).executeForFiles('./', ['a.dart', 'b.dart']);
      expect(runner.runCount, 1);
      final args = runner.lastArgs!;
      expect(args.sublist(args.indexOf('--') + 1), ['a.dart', 'b.dart']);
    });

    test('splits author counts per file', () async {
      final runner = MockProcessRunner(nameOnlyLog);
      final res = await BusFactorAlgorithm(
        runner,
      ).executeForFiles('./', ['a.dart', 'b.dart']);

      expect(res['a.dart']!.totalDevelopers, 1);
      expect(res['a.dart']!.topContributors.single.author, 'Alice');
      expect(res['a.dart']!.topContributors.single.contributions, 2);

      expect(res['b.dart']!.totalDevelopers, 2);
    });

    test('ignores files outside the target set', () async {
      final runner = MockProcessRunner(nameOnlyLog);
      final res = await BusFactorAlgorithm(
        runner,
      ).executeForFiles('./', ['a.dart', 'b.dart']);
      expect(res.containsKey('other.dart'), isFalse);
    });

    test('returns an empty DTO for a target file without history', () async {
      final runner = MockProcessRunner(nameOnlyLog);
      final res = await BusFactorAlgorithm(
        runner,
      ).executeForFiles('./', ['a.dart', 'missing.dart']);
      expect(res['missing.dart']!.totalDevelopers, 0);
      expect(res['missing.dart']!.busFactor, 0);
      expect(res['missing.dart']!.topContributors, isEmpty);
    });

    test('returns empty map for an empty target list', () async {
      final runner = MockProcessRunner(nameOnlyLog);
      final res = await BusFactorAlgorithm(runner).executeForFiles('./', []);
      expect(res, isEmpty);
      expect(runner.runCount, 0);
    });
  });
}
