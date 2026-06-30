import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

void main() {
  group('Library API (intelligence exports)', () {
    test('BusFactorAlgorithm is usable via package:rw_git/rw_git.dart',
        () async {
      final runner = MockProcessRunner();
      runner.setMockResult('git', ['log', '-n', '3', '--format=%an'], 0,
          'Alice\nAlice\nBob\n', '');

      final result = await BusFactorAlgorithm(runner).execute('.', limit: '3');

      expect(result, isA<BusFactorDto>());
      expect(result.totalDevelopers, 2);
    });

    test('BugHotspotsHeuristic is usable via package:rw_git/rw_git.dart',
        () async {
      final runner = MockProcessRunner();
      runner.setMockResult(
          'git',
          [
            'log',
            '--grep=fix\\|bug\\|patch\\|issue\\|resolv',
            '-i',
            '--no-merges',
            '--format=format:%H%x09%aI%x09%s'
          ],
          0,
          '',
          '');

      final result =
          await BugHotspotsHeuristic(runner).calculateBugHotspots('.');

      expect(result, isA<BugHotspotDto>());
    });

    test('SecretsScanner is usable via package:rw_git/rw_git.dart', () async {
      final runner = MockProcessRunner();
      runner.setMockResult(
          'git', ['log', '-p', '--format=%H||%an||%ad||%s'], 0, '', '');

      final result = await SecretsScanner(runner).findSecrets('.');

      expect(result, isA<List<String>>());
    });
  });
}
