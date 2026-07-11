// ignore_for_file: avoid_dynamic_calls, unnecessary_cast
import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

final invalidResult = "INVALID";
final testDir = "CHECKOUT_TEST_DIR";
final validRemoteRepository = "https://github.com/rw-core/rw-git";
final invalidRemoteRepository = "https://google.com";

void main() {
  late RwGit rwGit;

  setUp(() {
    rwGit = RwGit();
  });

  tearDown(() async {
    await Directory(testDir).delete(recursive: true);
  });

  /// Test group for [rwGit.checkout()] function.
  group('checkout', () {
    test(
      'will succeed on a valid git repository with a valid branch',
      () async {
        (await rwGit.clone(testDir, validRemoteRepository)).getOrThrow();
        List<FileSystemEntity> clonedFiles =
            await Directory(testDir).list().toList();

        bool isCheckoutSuccess =
            (await rwGit.checkout(
              clonedFiles[0].uri.path,
              "main",
            )).getOrThrow();
        expect(isCheckoutSuccess, true);
      },
    );

    test('will fail if the specified branch is invalid', () async {
      (await rwGit.clone(testDir, validRemoteRepository)).getOrThrow();
      try {
        (await rwGit.checkout(testDir, "invalid")).getOrThrow();
        fail('Should have thrown RwGitException');
      } on RwGitException catch (e) {
        expect(e.exitCode != 0, true);
      }
    });

    test('will sanitize branch name starting with hyphen', () async {
      (await rwGit.clone(testDir, validRemoteRepository)).getOrThrow();
      try {
        // -invalid-branch should become refs/heads/-invalid-branch instead of failing on git flag injection
        (await rwGit.checkout(testDir, "-invalid-branch")).getOrThrow();
        fail('Should have thrown RwGitException');
      } on RwGitException catch (e) {
        // the error output should reflect that it tried to checkout refs/heads/-invalid-branch
        expect(
          e.stderr?.contains('refs/heads/-invalid-branch') == true ||
              e.stderr?.contains('did not match') == true,
          true,
        );
      }
    });
  });
}
