import 'dart:io';

import '../../rw_git.dart';
import 'parsers/git_url_parser.dart';

abstract class BaseRwGit implements RwGit {
  @override
  final String invalidGitCommandResult = "INVALID";
  @override
  final String gitRepoIndicator = ".git";

  @override
  Future<bool> cloneSpecificBranch(String localDirectoryToCloneInto,
      String repository, String branchToCheckout,
      {bool streamOutput = false}) async {
    try {
      await clone(localDirectoryToCloneInto, repository,
          streamOutput: streamOutput);

      String localCheckoutDirectory = localDirectoryToCloneInto +
          Platform.pathSeparator +
          GitUrlParser.parseRepositoryNameFromRepositoryUrl(repository);

      return checkout(localCheckoutDirectory, branchToCheckout,
          streamOutput: streamOutput);
    } on RwGitException {
      return false;
    }
  }

  @override
  Future<ShortStatDto> cloneAndGetStatistics(String localDirectoryToCloneInto,
      String repository, String oldTag, String newTag,
      {bool streamOutput = false}) async {
    try {
      await clone(localDirectoryToCloneInto, repository,
          streamOutput: streamOutput);

      String localCheckoutDirectory = localDirectoryToCloneInto +
          Platform.pathSeparator +
          GitUrlParser.parseRepositoryNameFromRepositoryUrl(repository);

      return stats(localCheckoutDirectory, oldTag, newTag,
          streamOutput: streamOutput);
    } on RwGitException {
      return ShortStatDto.defaultStats();
    }
  }
}
