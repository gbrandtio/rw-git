import 'package:rw_git/src/git_service/parsers/git_url_parser.dart';
import 'package:test/test.dart';

void main() {
  group('GitUrlParser', () {
    test('given a valid github url, will return the repository name', () {
      final String repositoryName = 'rw-git';
      final String repositoryUrl = 'https://github.com/gbrandtio/rw-git';

      String parsedName =
          GitUrlParser.parseRepositoryNameFromRepositoryUrl(repositoryUrl);
      expect(parsedName, repositoryName);
    });

    test('given an invalid github URL, will just echo back the passed URL', () {
      final String repositoryUrl = 'google.com';

      String parsedName =
          GitUrlParser.parseRepositoryNameFromRepositoryUrl(repositoryUrl);
      expect(parsedName, repositoryUrl);
    });
  });
}
