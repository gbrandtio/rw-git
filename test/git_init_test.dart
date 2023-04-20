import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

final invalidResult = "INVALID";
final testDir = "TEST_DIR_INIT";

void main() {
  late RwGit rwGit;

  // Actions execution before every test.
  setUp(() {
    rwGit = RwGit();
  });

  /// Test group for [rwGit.init()] function.
  group('init', () {
    test('will create a local directory', () async {
      await rwGit.gitCommon.init(testDir);
      bool directoryExists = await Directory(testDir).exists();
      expect(directoryExists, true);
    });

    test('will initialize a git directory', () async {
      await rwGit.gitCommon.init(testDir);
      bool isGitDirectory = await rwGit.gitCommon.isGitRepository(testDir);
      expect(isGitDirectory, true);
      await Directory(testDir).delete(recursive: true);
    });
  });
}
