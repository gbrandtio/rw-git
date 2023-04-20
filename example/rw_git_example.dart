import 'dart:io';

import 'package:rw_git/rw_git.dart';

void main() async {
  // Initialize RwGit service.
  final rwGit = RwGit();

  // Initializations.
  final localDirectoryName = "RW_GIT";
  final oldTag = "v6.0.8";
  final newTag = "v7.0.0";
  final repositoryToClone =
      "https://github.com/jasontaylordev/CleanArchitecture";

  // Create a local directory and clone into it.
  String localDirectoryToCloneInto =
      _createCheckoutDirectory(localDirectoryName);
  rwGit.gitCommon.clone(localDirectoryToCloneInto, repositoryToClone);

  // Retrieve and count all the tags.
  List<String> tags = await rwGit.gitCommon.fetchTags(localDirectoryToCloneInto);
  print("Number of tags: ${tags.length}");

  // Count all commits between two tags.
  List<String> listOfCommitsBetweenTwoTags =
      await rwGit.gitCommon.getCommitsBetween(localDirectoryToCloneInto, oldTag, newTag);
  print(
      "Number of commits between $oldTag and $newTag: ${listOfCommitsBetweenTwoTags.length}");

  // Retrieve lines of code inserted, deleted and number of changed files
  // between two tags.
  ShortStatDto shortStatDto =
      await rwGit.gitStats.stats(localDirectoryToCloneInto, oldTag, newTag);
  print('Number of lines inserted: ${shortStatDto.insertions}'
      ' Number of lines deleted: ${shortStatDto.deletions}'
      ' Number of files changed: ${shortStatDto.numberOfChangedFiles}');
}

/// Creates the directory where the repository will be checked out,
/// If the directory already exists, it will delete it along with any content inside
/// and a new one will be created.
String _createCheckoutDirectory(String directoryName) {
  Directory checkoutDirectory = Directory(directoryName);
  try {
    checkoutDirectory.deleteSync(recursive: true);
  } catch (e) {
    // Handle the exception
  }
  checkoutDirectory.createSync();

  return "${Directory.current.path}\\$directoryName";
}
