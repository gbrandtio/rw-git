import 'dart:io';
import 'package:rw_git/src/git_service/rw_git_parser.dart';
import 'package:git/git.dart' as git_service;
import 'package:rw_git/src/models/short_log_dto.dart';
import 'package:rw_git/src/models/short_stat_dto.dart';

/// ----------------------------------------------------------------------------
/// rw_git_base.dart
/// ----------------------------------------------------------------------------
/// Offers a useful interface for executing various GIT commands and fetching a
/// pretty GIT result.
class RwGit {
  final invalidGitCommandResult = "INVALID";
  final gitRepoIndicator = ".git";

  /// Performs a `git init` in a local directory. If the supplied directory does
  /// not exist it will be created.
  Future<bool> init(String directoryToInit) async {
    await Directory(directoryToInit).create(recursive: true);
    ProcessResult processResult = await git_service.runGit(['init'],
        throwOnError: false,
        echoOutput: false,
        processWorkingDir: directoryToInit);

    return processResult.exitCode == 0;
  }

  /// Checks if the [directoryToCheck] is a git directory and returns true if
  /// it is, otherwise false. In order to determine if it is a git repository, it will check whether
  /// the repository belongs to a git tree.
  Future<bool> isGitRepository(String directoryToCheck) async {
    ProcessResult processResult = await git_service.runGit(
        ['rev-parse', '--is-inside-work-tree'],
        throwOnError: false,
        echoOutput: false,
        processWorkingDir: directoryToCheck);

    return processResult.stdout.toString().toLowerCase().trim() == "true";
  }

  /// Clones a repository by `git clone` into the specified [localDirectoryToCloneInto] folder.
  /// If the [localDirectoryToCloneInto] does not exist, it will be created.
  /// Returns true if the command was successful, false if failed for any reason.
  Future<bool> clone(
      String localDirectoryToCloneInto, String repository) async {
    await Directory(localDirectoryToCloneInto).create(recursive: true);
    ProcessResult processResult = await git_service.runGit(
        ['clone', repository],
        throwOnError: false,
        echoOutput: false,
        processWorkingDir: localDirectoryToCloneInto);

    return processResult.exitCode == 0;
  }

  /// `git checkout` the specified [branchToCheckout] on the [localCheckoutDirectory].
  /// Returns true if the operation has been completed successfully.
  Future<bool> checkout(
      String localCheckoutDirectory, String branchToCheckout) async {
    ProcessResult processResult = await git_service.runGit(
        ['checkout', branchToCheckout],
        throwOnError: false,
        echoOutput: false,
        processWorkingDir: localCheckoutDirectory);

    return processResult.exitCode == 0;
  }

  /// Lists all the tags of a directory by executing the `git tag -l` command.
  /// Returns a [List<String>] that contains the retrieved tags.
  /// [localCheckoutDirectory] - the local GIT directory to retrieve the tags.
  /// In case of success, will return a list with a tag name on each position, whereas in case of
  /// failure will return an empty list.
  Future<List<String>> fetchTags(String localCheckoutDirectory) async {
    ProcessResult processResult = await git_service.runGit(['tag', '-l'],
        echoOutput: false, processWorkingDir: localCheckoutDirectory);

    List<String> tags = RwGitParser.parseGitStdoutBasedOnNewLine(
        processResult.stdout.toString());
    return tags;
  }

  /// Executes the git command
  /// ```
  /// git rev-list oneTag anotherTag
  /// ```
  /// in order to fetch all the commits done between two tags.
  /// In case of success, will return a list with a commit hash on each position, whereas in case of
  /// failure will return an empty list.
  Future<List<String>> getCommitsBetween(
      String localCheckoutDirectory, String firstTag, String secondTag) async {
    String rawResult = "";

    ProcessResult processResult = await git_service.runGit(
        ['rev-list', '$firstTag...$secondTag'],
        throwOnError: false,
        echoOutput: false,
        processWorkingDir: localCheckoutDirectory);

    rawResult =
        processResult.stdout == null ? "" : processResult.stdout.toString();
    return RwGitParser.parseGitStdoutBasedOnNewLine(rawResult);
  }

  /// `git diff --shortstat oldTag newTag` to fetch statistics related to
  /// insertions, deletions and number of changed files between two tags.
  /// In case of success will return a [ShortStatDto] object with the available data,
  /// whereas an object with the default values otherwise.
  Future<ShortStatDto> stats(
      String localCheckoutDirectory, String oldTag, newTag) async {
    String rawResult = "";

    ProcessResult processResult = await git_service.runGit(
        ['diff', '--shortstat', oldTag, newTag],
        throwOnError: false,
        echoOutput: false,
        processWorkingDir: localCheckoutDirectory);

    rawResult = processResult.stdout;
    return RwGitParser.parseGitShortStatStdout(rawResult);
  }

  /// `git shortlog -s` to fetch author contributions.
  /// In case of success will return a [ShortLogDto] object with the available
  /// data, whereas an object with the default values otherwise.
  Future<List<ShortLogDto>> contributionsByAuthor(
      String localCheckoutDirectory) async {
    ProcessResult processResult = await Process.run('git', ['shortlog', 'HEAD', '-s'], workingDirectory: localCheckoutDirectory);

    List<String> rawList =
        RwGitParser.parseGitStdoutBasedOnNewLine(processResult.stdout);
    List<ShortLogDto> contributionsByAuthor =
        rawList.map((e) => RwGitParser.parseGitShortLogStdout(e)).toList();

    return contributionsByAuthor;
  }
}
