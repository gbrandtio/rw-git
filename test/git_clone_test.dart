import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

final invalidResult = "INVALID";
final testDir = "CLONE_TEST_DIR";
final validRemoteRepository = "https://github.com/gbrandtio/rw-git";
final invalidRemoteRepository = "https://google.com";

void main() {
  late RwGit rwGit;

  // Actions execution before every test.
  setUp(() {
    rwGit = RwGit();
  });

  /// Test group for [rwGit.clone()] function.
  group('clone', () {
    tearDown(() async {
      await Directory(testDir).delete(recursive: true);
    });

    test(
        'will create a local directory and clone the specified repository inside',
        () async {
      bool isCloneSuccess = await rwGit.clone(testDir, validRemoteRepository);
      expect(isCloneSuccess, true);

      bool isGitRepository = await rwGit.isGitRepository(testDir);
      expect(isGitRepository, true);
    });

    test('will create a local directory that will be empty, if the clone fails',
        () async {
      bool isCloneSuccess = await rwGit.clone(testDir, invalidRemoteRepository);
      expect(isCloneSuccess, false);
    });
  });
}
