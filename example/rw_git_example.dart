import 'dart:io';

import 'package:rw_git/rw_git.dart';
import 'package:path/path.dart' as p;

void main() async {
  // 1. Initialize RwGit service.
  final rwGit = RwGit();

  // Initializations.
  final localDirectoryName = "RW_GIT";
  final repositoryToClone =
      "https://github.com/jasontaylordev/CleanArchitecture";

  // Create a local directory and clone into it.
  String localDirectoryToCloneInto = _createCheckoutDirectory(
    localDirectoryName,
  );

  print("Cloning repository...");
  final cloneResult = await rwGit.clone(
    localDirectoryToCloneInto,
    repositoryToClone,
  );

  // You can use getOrThrow() to easily extract the value or throw if it's an error.
  cloneResult.getOrThrow();
  print("Repository cloned successfully!\n");

  // 2. Branch: Retrieve the branches of the repository
  List<GitBranch> branches =
      (await rwGit.branch(localDirectoryToCloneInto)).getOrThrow();
  print("Number of branches: ${branches.length}");
  final currentBranch = branches.firstWhere(
    (b) => b.isCurrent,
    orElse: () => branches.first,
  );
  print("Current branch: ${currentBranch.name}\n");

  // 3. Status: Check working directory state
  GitStatus status =
      (await rwGit.status(localDirectoryToCloneInto)).getOrThrow();
  print("Initial Status - Untracked files: ${status.untrackedFiles.length}");

  // Modify a file to showcase diff and status
  final dummyFile = File(p.join(localDirectoryToCloneInto, "dummy.txt"));
  dummyFile.writeAsStringSync("Hello, RwGit!");

  status = (await rwGit.status(localDirectoryToCloneInto)).getOrThrow();
  print("Modified Status - Untracked files: ${status.untrackedFiles.length}\n");

  // 4. Show: View the HEAD commit details
  GitCommit headCommit =
      (await rwGit.show(
        localDirectoryToCloneInto,
        extraArgs: ["HEAD"],
      )).getOrThrow();
  print("HEAD Commit Details:");
  print("  Hash: ${headCommit.hash}");
  print("  Author: ${headCommit.authorName} <${headCommit.authorEmail}>");
  print("  Message: ${headCommit.message}\n");

  // 5. Retrieve the tags of the repository
  List<GitTag> tags =
      (await rwGit.fetchTags(localDirectoryToCloneInto)).getOrThrow();
  print("Number of tags: ${tags.length}\n");

  if (tags.length >= 2) {
    final oldTag = tags[0].name;
    final newTag = tags.last.name;

    // 6. Get the commits between two tags
    List<GitCommit> listOfCommitsBetweenTwoTags =
        (await rwGit.getCommitsBetween(
          localDirectoryToCloneInto,
          oldTag,
          newTag,
        )).getOrThrow();
    print(
      "Number of commits between $oldTag and $newTag: ${listOfCommitsBetweenTwoTags.length}\n",
    );

    // 7. Retrieve lines of code inserted, deleted and number of changed files
    // between two tags.
    ShortStatDto shortStatDto =
        (await rwGit.stats(
          localDirectoryToCloneInto,
          oldTag,
          newTag,
        )).getOrThrow();
    print('Number of lines inserted: ${shortStatDto.insertions}');
    print('Number of lines deleted: ${shortStatDto.deletions}');
    print('Number of files changed: ${shortStatDto.numberOfChangedFiles}\n');
  }
}

/// Creates the directory where the repository will be checked out.
/// If the directory already exists, it will delete it along with any content inside
/// and a new one will be created.
String _createCheckoutDirectory(String directoryName) {
  Directory checkoutDirectory = Directory(directoryName);
  try {
    checkoutDirectory.deleteSync(recursive: true);
  } catch (e) {
    // Handle the exception, e.g. directory doesn't exist
  }
  checkoutDirectory.createSync();

  return "${Directory.current.path}${Platform.pathSeparator}$directoryName";
}
