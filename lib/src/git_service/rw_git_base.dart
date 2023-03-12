import 'dart:io';
import 'package:rw_git/src/git_service/git_output_parser.dart';
import 'package:git/git.dart' as git_service;
import 'package:rw_git/src/models/short_stat_dto.dart';

/// ----------------------------------------------------------------------------
/// rw_git_base.dart
/// ----------------------------------------------------------------------------
/// Offers a useful interface for executing various GIT commands and fetching a
/// pretty GIT result.
class RwGit {
  final invalidGitCommandResult = "INVALID";

  /// Performs a `git init` in a local directory. If the supplied directory does
  /// not exist it will be created.
  Future<bool> init(String directoryToInit) async {
    await Directory(directoryToInit).create(recursive: true);
    ProcessResult processResult = await git_service.runGit(['init'],
        echoOutput: false, processWorkingDir: directoryToInit);

    return processResult.exitCode == 0;
  }

  /// Clones a repository by `git clone` into the specified [localDirectoryToCloneInto] folder.
  /// If the [localDirectoryToCloneInto] does not exist, it will be created.
  /// Returns true if the command was successful.
  /// NOTES:
  /// * Even if the [git clone] is successful, the return code will not be 0. There
  ///   isn't a reliable way of determining the success / failure of the command.
  Future<bool> clone(
      String localDirectoryToCloneInto, String repository) async {
    await Directory(localDirectoryToCloneInto).create(recursive: true);
    await git_service.runGit(['clone', repository],
        echoOutput: false, processWorkingDir: localDirectoryToCloneInto);
    return true;
  }

  /// `git checkout` the specified [branchToCheckout] on the [localCheckoutDirectory].
  /// Returns true if the operation has been completed successfully.
  Future<bool> checkout(
      String localCheckoutDirectory, String branchToCheckout) async {
    ProcessResult processResult = await git_service.runGit(
        ['checkout', branchToCheckout],
        echoOutput: false, processWorkingDir: localCheckoutDirectory);

    return processResult.exitCode == 0;
  }

  /// Lists all the tags of a directory by executing the `git tag -l` command.
  /// Returns a [List<String>] that contains the retrieved tags.
  /// [localCheckoutDirectory] - the local GIT directory to retrieve the tags.
  Future<List<String>> fetchTags(String localCheckoutDirectory) async {
    ProcessResult processResult = await git_service.runGit(['tag', '-l'],
        echoOutput: false, processWorkingDir: localCheckoutDirectory);
    List<String> tags = GitOutputParser.parseGitStdoutBasedOnNewLine(
        processResult.stdout.toString());
    return tags;
  }

  /// Executes the git command
  /// ```
  /// git rev-list oneTag anotherTag
  /// ```
  /// in order to fetch all the commits done between two tags.
  /// Returns a raw [List<String>] that contains the command output.
  Future<List<String>> getCommitsBetween(
      String localCheckoutDirectory, String firstTag, String secondTag) async {
    String rawResult = "";

    try {
      ProcessResult processResult = await git_service.runGit(
          ['rev-list', '$firstTag...$secondTag'],
          echoOutput: true, processWorkingDir: localCheckoutDirectory);

      rawResult = processResult.stdout;
    } catch (e) {
      rawResult = invalidGitCommandResult;
    }

    return GitOutputParser.parseGitStdoutBasedOnNewLine(rawResult);
  }

  /// `git --shortstat oldTag newTag` to fetch statistics related to
  /// insertions, deletions and number of changed files between two tags.
  Future<ShortStatDto> stats(
      String localCheckoutDirectory, String oldTag, newTag) async {
    String rawResult = "";

    try {
      ProcessResult processResult = await git_service.runGit(
          ['diff', '--shortstat', oldTag, newTag],
          echoOutput: false, processWorkingDir: localCheckoutDirectory);

      rawResult = processResult.stdout;
    } catch (e) {
      rawResult = invalidGitCommandResult;
    }

    return GitOutputParser.parseGitShortStatStdout(rawResult);
  }
}
