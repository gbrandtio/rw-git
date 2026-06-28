import 'dart:io';

import '../../rw_git.dart';
import '../core/result.dart';
import 'parsers/git_url_parser.dart';

abstract class BaseRwGit implements RwGit {
  @override
  final String invalidGitCommandResult = "INVALID";
  @override
  final String gitRepoIndicator = ".git";

  @override
  Future<Result<bool, RwGitException>> cloneSpecificBranch(
      String localDirectoryToCloneInto,
      String repository,
      String branchToCheckout,
      {bool streamOutput = false}) async {
    final cloneResult = await clone(localDirectoryToCloneInto, repository,
        streamOutput: streamOutput);

    return cloneResult.fold((_) {
      String localCheckoutDirectory = localDirectoryToCloneInto +
          Platform.pathSeparator +
          GitUrlParser.parseRepositoryNameFromRepositoryUrl(repository);

      return checkout(localCheckoutDirectory, branchToCheckout,
          streamOutput: streamOutput);
    }, (e) => Failure(e));
  }
}
