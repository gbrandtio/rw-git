import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

final invalidResult = "INVALID";
final testDir = "CHECKOUT_TEST_DIR";
final validRemoteRepository = "https://github.com/gbrandtio/rw-git";
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
    test('will succeed on a valid git repository with a valid branch',
        () async {
      await rwGit.clone(testDir, validRemoteRepository);
      bool isCheckoutSuccess = await rwGit.checkout(testDir, "main");

      expect(isCheckoutSuccess, true);
    });

    test('will fail if the specified branch is invalid', () async {
      await rwGit.clone(testDir, validRemoteRepository);
      bool isCheckoutSuccess = await rwGit.checkout(testDir, "invalid");

      expect(isCheckoutSuccess, false);
    });
  });
}
