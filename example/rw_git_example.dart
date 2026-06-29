import 'dart:io';

import 'package:rw_git/rw_git.dart';

void main() async {
  // 1. Initialize RwGit service.
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

  print("Cloning repository...");
  final cloneResult =
      await rwGit.clone(localDirectoryToCloneInto, repositoryToClone);

  // You can use getOrThrow() to easily extract the value or throw if it's an error.
  cloneResult.getOrThrow();
  print("Repository cloned successfully!\n");

  // 2. Retrieve the tags of the repository
  List<GitTag> tags =
      (await rwGit.fetchTags(localDirectoryToCloneInto)).getOrThrow();
  print("Number of tags: ${tags.length}\n");

  // 3. Get the commits between two tags
  List<GitCommit> listOfCommitsBetweenTwoTags =
      (await rwGit.getCommitsBetween(localDirectoryToCloneInto, oldTag, newTag))
          .getOrThrow();
  print(
      "Number of commits between $oldTag and $newTag: ${listOfCommitsBetweenTwoTags.length}\n");

  // 4. Retrieve lines of code inserted, deleted and number of changed files
  // between two tags.
  ShortStatDto shortStatDto =
      (await rwGit.stats(localDirectoryToCloneInto, oldTag, newTag))
          .getOrThrow();
  print('Number of lines inserted: ${shortStatDto.insertions}');
  print('Number of lines deleted: ${shortStatDto.deletions}');
  print('Number of files changed: ${shortStatDto.numberOfChangedFiles}\n');

  // 5. Code Quality and Analytics (New Feature)
  print("Running Code Quality and Analytics Tools...");
  final processRunner = ProcessRunner.defaultRunner();
  final qualityTracker = CodeQualityTracker(processRunner);

  // 5.1 Calculate Code Churn
  final churnMetrics = await qualityTracker
      .calculateChurn(localDirectoryToCloneInto, limit: "50");
  print("Analyzed ${churnMetrics.totalCommits} commits for churn metrics.");

  // 5.2 Find Suspicious Commits (e.g., TODOs, FIXMEs, workarounds)
  final suspiciousCommits = await qualityTracker
      .findSuspiciousCommits(localDirectoryToCloneInto, limit: "100");
  print(
      "Found ${suspiciousCommits.length} commits containing suspicious keywords.");

  // 5.3 Commit Velocity
  final commitVelocity = await qualityTracker
      .calculateCommitVelocity(localDirectoryToCloneInto, granularity: "month");
  print(
      "Commit Velocity trend: ${commitVelocity.trend} (Avg: ${commitVelocity.averagePerPeriod.toStringAsFixed(1)} commits/month).\n");
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
