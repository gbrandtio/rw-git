import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
    final rwGit = RwGit();

    test('The count of commits is zero if the given directory or tags do not exist' , () async {
      List<String> commitsBetweenTags = await rwGit.getCommitsBetween('./extinct', 'v1.0.0_extinct', 'v1.0.1_extinct');
      int countOfCommits = commitsBetweenTags.length;

      expect(countOfCommits, 0);
    });
  });
}
