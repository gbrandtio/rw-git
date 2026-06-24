import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

void main() {
  group('MockProcessRunner Tests', () {
    late RwGit rwGit;
    late MockProcessRunner mockRunner;

    setUp(() {
      mockRunner = MockProcessRunner();
      rwGit = RwGit(runner: mockRunner);
    });

    test('clone uses mock runner and parses stdout correctly', () async {
      mockRunner.setMockResult('git', ['clone', '--', 'https://fake.url/repo.git'], 0, 'Cloning into repo...', '');
      
      final result = await rwGit.clone('my_dir', 'https://fake.url/repo.git');
      expect(result, true);
    });

    test('clone handles mock failure', () async {
      mockRunner.setMockResult('git', ['clone', '--', 'bad_url'], 128, '', 'fatal: repository not found');
      
      try {
        await rwGit.clone('my_dir', 'bad_url');
        fail('Should have thrown RwGitException');
      } on RwGitException catch (e) {
        expect(e.exitCode, 128);
        expect(e.stderr, 'fatal: repository not found');
      }
    });

    test('stats parses mock shortstat correctly', () async {
      mockRunner.setMockResult('git', ['diff', '--shortstat', 'v1', 'v2'], 0, ' 3 files changed, 50 insertions(+), 10 deletions(-)', '');
      
      final stats = await rwGit.stats('my_dir', 'v1', 'v2');
      expect(stats.numberOfChangedFiles, 3);
      expect(stats.insertions, 50);
      expect(stats.deletions, 10);
    });
  });
}
