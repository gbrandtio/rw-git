/// ----------------------------------------------------------------------------
/// git_url_parser.dart
/// ----------------------------------------------------------------------------
/// Provides functionality specific to parsing git URLs.
class GitUrlParser {
  static const String repositoryUrlSplitter = "/";

  /// Parses the repository name of the provided git repository URL.
  /// If the parsing fails, will echo back the passed URL.
  static String parseRepositoryNameFromRepositoryUrl(String repositoryUrl) {
    List<String> parts = repositoryUrl.split(repositoryUrlSplitter);
    String repositoryName = repositoryUrl;

    if (parts.isNotEmpty) {
      repositoryName = parts.last;
    }

    return repositoryName;
  }
}
