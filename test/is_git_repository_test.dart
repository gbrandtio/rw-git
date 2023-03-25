import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

final invalidResult = "INVALID";
final testDir = "INIT_TEST_DIR";

void main() {
  late RwGit rwGit;

  // Actions execution before every test.
  setUp(() {
    rwGit = RwGit();
  });

  tearDown(() async {});

  /// Test group for [rwGit.isGitRepository()] function.
  group('isGitRepository', () {
    test('will succeed if the specified repository is a git repository',
        () async {
      await rwGit.init(testDir);
      bool isGitRepository = await rwGit.isGitRepository(testDir);

      expect(isGitRepository, true);
      await Directory(testDir).delete(recursive: true);
    });
  });
}
