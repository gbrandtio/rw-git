import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

void main() {
  group('Ensures that', () {
    final rwGit = RwGit();

    test(
        'if the repository does not exist, the output contains only one INVALID entry',
        () async {
      List<String> commitsBetweenTags = await rwGit.getCommitsBetween(
          './extinct', 'v1.0.0_extinct', 'v1.0.1_extinct');

      expect(commitsBetweenTags[0], "INVALID");
    });

    test(
        'the count of commits is zero if the given directory or tags do not exist',
        () async {
      List<String> commitsBetweenTags = await rwGit.getCommitsBetween(
          './extinct', 'v1.0.0_extinct', 'v1.0.1_extinct');

      // Remove the INVALID entries
      commitsBetweenTags.removeWhere((element) => element == "INVALID");
      int countOfCommits = commitsBetweenTags.length;
      expect(countOfCommits, 0);
    });
  });
}
