import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

final invalidResult = "INVALID";

void main() {
  late RwGit rwGit;

  // Actions execution before every test.
  setUp(() {
    rwGit = RwGit();
  });

  /// Test group for [rwGit.getCommitsBetween()] function.
  group('getCommitsBetween', () {
    test('returns a List with one entry which is equal to INVALID', () async {
      List<String> commitsBetweenTags = await rwGit.getCommitsBetween(
          './extinct', 'v1.0.0_extinct', 'v1.0.1_extinct');

      expect(commitsBetweenTags[0], invalidResult);
    });

    test(
        'output length will be 0, if we do not take into consideration the INVALID entry',
        () async {
      List<String> commitsBetweenTags = await rwGit.getCommitsBetween(
          './extinct', 'v1.0.0_extinct', 'v1.0.1_extinct');

      commitsBetweenTags.removeWhere((element) => element == invalidResult);
      int countOfCommits = commitsBetweenTags.length;
      expect(countOfCommits, 0);
    });
  });
}
