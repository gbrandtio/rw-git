import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

void main() {
  late RwGit rwGit;
  late ProcessRunner runner;
  late String testDir;

  setUp(() {
    rwGit = RwGit();
    runner = ProcessRunner.defaultRunner();
    testDir = Directory.systemTemp.createTempSync('rw_git_e2e_').path;
  });

  tearDown(() {
    final dir = Directory(testDir);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  // Test fixture setup (config/add/commit) goes straight through the process
  // runner: the public facade deliberately offers no arbitrary git execution.
  Future<void> runGit(List<String> args) async {
    final result = await runner.run('git', args, workingDirectory: testDir);
    expect(
      result.exitCode,
      0,
      reason: 'git ${args.join(' ')} failed: ${result.stderr}',
    );
  }

  group('End-to-End Integration Tests', () {
    test(
      'creates a repo, makes a commit, branches, and merges successfully',
      () async {
        // 1. Init
        final initResult = await rwGit.init(testDir);
        expect(initResult.isSuccess, isTrue);

        // Configure git user for CI environments
        await runGit(['config', 'user.email', 'test@example.com']);
        await runGit(['config', 'user.name', 'E2E Test Runner']);

        // Create a dummy file
        final file = File(p.join(testDir, 'test_file.txt'));
        file.writeAsStringSync('Hello, E2E!');

        // 2. Add
        await runGit(['add', 'test_file.txt']);

        // 3. Status
        final statusResult = await rwGit.status(testDir);
        expect(statusResult.isSuccess, isTrue);
        expect(
          statusResult.getOrThrow().stagedChanges.map((e) => e.path),
          contains('test_file.txt'),
        );

        // 4. Commit
        await runGit(['commit', '-m', 'Initial commit']);

        // 5. Branch
        final branchResult = await rwGit.branch(
          testDir,
          extraArgs: ['feature-branch'],
        );
        expect(branchResult.isSuccess, isTrue);

        // 6. Checkout
        final checkoutResult = await rwGit.checkout(testDir, 'feature-branch');
        expect(checkoutResult.isSuccess, isTrue);

        // Modify the file on feature branch
        file.writeAsStringSync('Hello, E2E from feature branch!');
        await runGit(['add', 'test_file.txt']);
        await runGit(['commit', '-m', 'Feature commit']);

        // 7. Checkout main
        final checkoutMainResult = await rwGit.checkout(testDir, 'main');
        // Some old git versions default to master, some main. We will check both.
        if (!checkoutMainResult.isSuccess) {
          final checkoutMasterResult = await rwGit.checkout(testDir, 'master');
          expect(checkoutMasterResult.isSuccess, isTrue);
        }

        // 8. Merge
        final mergeResult = await rwGit.merge(
          testDir,
          extraArgs: ['feature-branch'],
        );
        expect(mergeResult.isSuccess, isTrue);

        // 9. Log (Show)
        final showResult = await rwGit.show(testDir);
        expect(showResult.isSuccess, isTrue);
        expect(showResult.getOrThrow().message, contains('Feature commit'));
      },
    );
  });
}
