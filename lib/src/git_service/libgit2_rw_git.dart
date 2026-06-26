import 'package:libgit2dart/libgit2dart.dart';
import '../../rw_git.dart';
import 'base_rw_git.dart';

/// Stub implementation for libgit2 integration (FFI-based).
/// This implementation will be expanded to support mobile platforms
/// where the system 'git' executable is unavailable.
class LibGit2RwGit extends BaseRwGit {
  LibGit2RwGit();

  @override
  Future<bool> init(String directoryToInit, {bool streamOutput = false}) async {
    try {
      Repository.init(path: directoryToInit);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> isGitRepository(String directoryToCheck,
      {bool streamOutput = false}) async {
    try {
      final repo = Repository.open(directoryToCheck);
      repo.free();
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> clone(String localDirectoryToCloneInto, String repository,
      {bool streamOutput = false}) async {
    try {
      final repo = Repository.clone(
          url: repository, localPath: localDirectoryToCloneInto);
      repo.free();
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> checkout(String localCheckoutDirectory, String branchToCheckout,
      {bool streamOutput = false}) async {
    try {
      final repo = Repository.open(localCheckoutDirectory);
      repo.setHead('refs/heads/$branchToCheckout');
      Checkout.head(repo: repo);
      repo.free();
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<String>> fetchTags(String localCheckoutDirectory,
      {bool streamOutput = false}) async {
    try {
      final repo = Repository.open(localCheckoutDirectory);
      final tags = repo.tags;
      repo.free();
      return tags;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<String>> getCommitsBetween(
      String localCheckoutDirectory, String firstTag, String secondTag,
      {bool streamOutput = false}) async {
    try {
      final repo = Repository.open(localCheckoutDirectory);
      final walker = RevWalk(repo)..pushRange('$firstTag..$secondTag');
      final commits = walker.walk();

      final result = commits.map((c) {
        final sha = c.oid.sha;
        final message = c.message.split('\n').first;
        return '$sha $message';
      }).toList();

      for (final c in commits) {
        c.free();
      }
      walker.free();
      repo.free();

      return result;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<ShortStatDto> stats(
      String localCheckoutDirectory, String oldTag, String newTag,
      {bool streamOutput = false}) async {
    try {
      final repo = Repository.open(localCheckoutDirectory);

      final oldRef = Reference.lookup(repo: repo, name: 'refs/tags/$oldTag');
      final newRef = Reference.lookup(repo: repo, name: 'refs/tags/$newTag');

      final oldCommit = Commit.lookup(repo: repo, oid: oldRef.target);
      final newCommit = Commit.lookup(repo: repo, oid: newRef.target);

      final diff = Diff.treeToTree(
          repo: repo, oldTree: oldCommit.tree, newTree: newCommit.tree);
      final stats = diff.stats;

      final statDto =
          ShortStatDto(stats.insertions, stats.deletions, stats.filesChanged);

      stats.free();
      diff.free();
      oldCommit.free();
      newCommit.free();
      oldRef.free();
      newRef.free();
      repo.free();

      return statDto;
    } catch (e) {
      return ShortStatDto.defaultStats();
    }
  }

  @override
  Future<List<ShortLogDto>> contributionsByAuthor(String localCheckoutDirectory,
      {bool streamOutput = false}) async {
    try {
      final repo = Repository.open(localCheckoutDirectory);
      final walker = RevWalk(repo)..pushHead();
      final commits = walker.walk();

      final counts = <String, Map<String, dynamic>>{};

      for (final commit in commits) {
        final author = commit.author;
        final key = '${author.name} <${author.email}>';
        if (!counts.containsKey(key)) {
          counts[key] = {'name': author.name, 'commits': 0};
        }
        counts[key]!['commits'] = (counts[key]!['commits'] as int) + 1;
        commit.free();
      }

      walker.free();
      repo.free();

      final result = counts.values
          .map((data) =>
              ShortLogDto(data['commits'] as int, data['name'] as String))
          .toList();
      result.sort(
          (a, b) => b.numberOfContributions.compareTo(a.numberOfContributions));
      return result;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<String> runCommand(String directory, List<String> args,
      {bool streamOutput = false}) async {
    final runner = ProcessRunner.defaultRunner();
    final result = await runner.run('git', args,
        workingDirectory: directory, streamOutput: streamOutput);
    evaluateProcessResult(result);
    return result.stdout?.toString() ?? '';
  }
}
