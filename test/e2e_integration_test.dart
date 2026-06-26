import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

void main() {
  late RwGit rwGit;
  late String testDir;

  setUp(() {
    rwGit = RwGit();
    testDir = Directory.systemTemp.createTempSync('rw_git_e2e_').path;
  });

  tearDown(() {
    final dir = Directory(testDir);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  group('End-to-End Integration Tests', () {
    test('creates a repo, makes a commit, branches, and merges successfully',
        () async {
      // 1. Init
      final initResult = await rwGit.init(testDir);
      expect(initResult.isSuccess, isTrue);

      // Create a dummy file
      final file = File(p.join(testDir, 'test_file.txt'));
      file.writeAsStringSync('Hello, E2E!');

      // 2. Add (using runCommand)
      final addResult =
          await rwGit.runCommand(testDir, ['add', 'test_file.txt']);
      expect(addResult.isSuccess, isTrue);

      // 3. Status
      final statusResult = await rwGit.status(testDir);
      expect(statusResult.isSuccess, isTrue);
      expect(statusResult.getOrThrow(), contains('A  test_file.txt'));

      // 4. Commit (using runCommand)
      final commitResult =
          await rwGit.runCommand(testDir, ['commit', '-m', 'Initial commit']);
      expect(commitResult.isSuccess, isTrue);

      // 5. Branch
      final branchResult =
          await rwGit.branch(testDir, extraArgs: ['feature-branch']);
      expect(branchResult.isSuccess, isTrue);

      // 6. Checkout
      final checkoutResult = await rwGit.checkout(testDir, 'feature-branch');
      expect(checkoutResult.isSuccess, isTrue);

      // Modify the file on feature branch
      file.writeAsStringSync('Hello, E2E from feature branch!');
      await rwGit.runCommand(testDir, ['add', 'test_file.txt']);
      await rwGit.runCommand(testDir, ['commit', '-m', 'Feature commit']);

      // 7. Checkout main
      final checkoutMainResult = await rwGit.checkout(testDir, 'main');
      // Some old git versions default to master, some main. We will check both.
      if (!checkoutMainResult.isSuccess) {
        final checkoutMasterResult = await rwGit.checkout(testDir, 'master');
        expect(checkoutMasterResult.isSuccess, isTrue);
      }

      // 8. Merge
      final mergeResult =
          await rwGit.merge(testDir, extraArgs: ['feature-branch']);
      expect(mergeResult.isSuccess, isTrue);

      // 9. Log (Show)
      final showResult = await rwGit.show(testDir);
      expect(showResult.isSuccess, isTrue);
      expect(showResult.getOrThrow(), contains('Feature commit'));
    });
  });
}
