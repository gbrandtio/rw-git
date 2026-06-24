import '../mcp_tool.dart';

/// get_rw_git_documentation_tool.dart
/// Provides detailed documentation for the RwGit facade out-of-the-box operations.

class GetRwGitDocumentationTool implements McpTool {
  @override
  String get name => 'get_rw_git_documentation';

  @override
  String get description => 'Retrieve detailed descriptions and parameter requirements for all RwGit facade out-of-the-box operations.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {},
        'required': []
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    return '''
# RwGit Facade Documentation

RwGit provides several out-of-the-box operations to simplify Git interactions.
Below is the list of available functions and their parameters:

1.  **init(String directoryToInit)**
    Initializes a new Git repository in the specified `directoryToInit`.
    Returns a `Future<bool>` indicating success.

2.  **isGitRepository(String directoryToCheck)**
    Checks if the specified `directoryToCheck` is a valid Git repository.
    Returns a `Future<bool>`.

3.  **clone(String localDirectoryToCloneInto, String repository)**
    Clones the remote `repository` URL into `localDirectoryToCloneInto`.
    Returns a `Future<bool>` indicating success.

4.  **checkout(String localCheckoutDirectory, String branchToCheckout)**
    Checks out the specified `branchToCheckout` within the `localCheckoutDirectory`.
    Returns a `Future<bool>` indicating success.

5.  **fetchTags(String localCheckoutDirectory)**
    Fetches all tags from the remote for the repository in `localCheckoutDirectory`.
    Returns a `Future<List<String>>` containing the tags.

6.  **getCommitsBetween(String localCheckoutDirectory, String firstTag, String secondTag)**
    Retrieves all commits between `firstTag` and `secondTag` in the specified directory.
    Returns a `Future<List<String>>` of commit logs.

7.  **stats(String localCheckoutDirectory, String oldTag, String newTag)**
    Retrieves code statistics (insertions, deletions) between `oldTag` and `newTag`.
    Returns a `Future<ShortStatDto>`.

8.  **contributionsByAuthor(String localCheckoutDirectory)**
    Retrieves the shortlog summary of contributions by each author.
    Returns a `Future<List<ShortLogDto>>`.

9.  **cloneSpecificBranch(String localDirectoryToCloneInto, String repository, String branchToCheckout)**
    Clones the `repository` and immediately checks out `branchToCheckout`.
    Returns a `Future<bool>`.

10. **cloneAndGetStatistics(String localDirectoryToCloneInto, String repository, String oldTag, String newTag)**
    Clones the `repository` and then retrieves the statistics between `oldTag` and `newTag`.
    Returns a `Future<ShortStatDto>`.

11. **runCommand(String directory, List<String> args)**
    A generic command executor to support any raw Git command by passing a list of `args` to run within `directory`.
    Returns a `Future<String>` containing the stdout output.
''';
  }
}
