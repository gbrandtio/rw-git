// ignore_for_file: avoid_dynamic_calls, unnecessary_cast
import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

final invalidResult = "INVALID";
final testDir = "CLONE_TEST_DIR";
final validRemoteRepository = "https://github.com/rw-core/rw-git";
final invalidRemoteRepository = "https://google.com";

void main() {
  late RwGit rwGit;

  // Actions execution before every test.
  setUp(() {
    rwGit = RwGit();
  });

  tearDown(() async {
    await Directory(testDir).delete(recursive: true);
  });

  /// Test group for [rwGit.clone()] function.
  group('clone', () {
    test(
      'will create a local directory and clone the specified repository inside',
      () async {
        bool isCloneSuccess =
            (await rwGit.clone(testDir, validRemoteRepository)).getOrThrow();
        expect(isCloneSuccess, true);
      },
    );

    test(
      'will create a local directory that will be empty, if the clone fails',
      () async {
        try {
          (await rwGit.clone(testDir, invalidRemoteRepository)).getOrThrow();
          fail('Should have thrown RwGitException');
        } on RwGitException catch (e) {
          expect(e.exitCode != 0, true);
        }
      },
    );
  });
}
