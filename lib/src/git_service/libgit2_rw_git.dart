import 'package:git2dart/git2dart.dart';
import '../../rw_git.dart';
import '../core/result.dart';
import 'base_rw_git.dart';

/// Stub implementation for libgit2 integration (FFI-based).
/// This implementation will be expanded to support mobile platforms
/// where the system 'git' executable is unavailable.
class _AuthorCount {
  final String name;
  int commits;

  _AuthorCount(this.name, this.commits);
}

class LibGit2RwGit extends BaseRwGit {
  LibGit2RwGit();

  @override
  Future<Result<bool, RwGitException>> init(String directoryToInit,
      {bool streamOutput = false}) async {
    try {
      Repository.init(path: directoryToInit);
      return const Success(true);
    } catch (e) {
      return Failure(
          RwGitException(message: 'LibGit2 init failed', originalException: e));
    }
  }

  @override
  Future<Result<bool, RwGitException>> isGitRepository(String directoryToCheck,
      {bool streamOutput = false}) async {
    try {
      final repo = Repository.open(directoryToCheck);
      repo.free();
      return const Success(true);
    } catch (e) {
      return Failure(RwGitException(
          message: 'LibGit2 isGitRepository failed', originalException: e));
    }
  }

  @override
  Future<Result<bool, RwGitException>> clone(
      String localDirectoryToCloneInto, String repository,
      {bool streamOutput = false}) async {
    try {
      final repo = Repository.clone(
          url: repository, localPath: localDirectoryToCloneInto);
      repo.free();
      return const Success(true);
    } catch (e) {
      return Failure(RwGitException(
          message: 'LibGit2 clone failed', originalException: e));
    }
  }

  @override
  Future<Result<bool, RwGitException>> checkout(
      String localCheckoutDirectory, String branchToCheckout,
      {bool streamOutput = false}) async {
    try {
      final repo = Repository.open(localCheckoutDirectory);
      repo.setHead('refs/heads/$branchToCheckout');
      Checkout.head(repo: repo);
      repo.free();
      return const Success(true);
    } catch (e) {
      return Failure(RwGitException(
          message: 'LibGit2 checkout failed', originalException: e));
    }
  }

  @override
  Future<Result<List<String>, RwGitException>> fetchTags(
      String localCheckoutDirectory,
      {bool streamOutput = false}) async {
    try {
      final repo = Repository.open(localCheckoutDirectory);
      final tags = repo.tags;
      repo.free();
      return Success(tags);
    } catch (e) {
      return Failure(RwGitException(
          message: 'LibGit2 fetchTags failed', originalException: e));
    }
  }

  @override
  Future<Result<List<String>, RwGitException>> getCommitsBetween(
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

      return Success(result);
    } catch (e) {
      return Failure(RwGitException(
          message: 'LibGit2 getCommitsBetween failed', originalException: e));
    }
  }

  @override
  Future<Result<ShortStatDto, RwGitException>> stats(
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

      return Success(statDto);
    } catch (e) {
      return Failure(RwGitException(
          message: 'LibGit2 stats failed', originalException: e));
    }
  }

  @override
  Future<Result<List<ShortLogDto>, RwGitException>> contributionsByAuthor(
      String localCheckoutDirectory,
      {bool streamOutput = false}) async {
    try {
      final repo = Repository.open(localCheckoutDirectory);
      final walker = RevWalk(repo)..pushHead();
      final commits = walker.walk();

      final counts = <String, _AuthorCount>{};

      for (final commit in commits) {
        final author = commit.author;
        final key = '${author.name} <${author.email}>';
        if (!counts.containsKey(key)) {
          counts[key] = _AuthorCount(author.name, 0);
        }
        counts[key]!.commits++;
        commit.free();
      }

      walker.free();
      repo.free();

      final result = counts.values
          .map((data) => ShortLogDto(data.commits, data.name))
          .toList();
      result.sort(
          (a, b) => b.numberOfContributions.compareTo(a.numberOfContributions));
      return Success(result);
    } catch (e) {
      return Failure(RwGitException(
          message: 'LibGit2 contributionsByAuthor failed',
          originalException: e));
    }
  }

  @override
  Future<Result<List<String>, RwGitException>> branch(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) async {
    return Failure(
        RwGitException(message: 'LibGit2 branch not implemented yet'));
  }

  @override
  Future<Result<String, RwGitException>> status(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) async {
    return Failure(
        RwGitException(message: 'LibGit2 status not implemented yet'));
  }

  @override
  Future<Result<bool, RwGitException>> pull(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) async {
    return Failure(RwGitException(message: 'LibGit2 pull not implemented yet'));
  }

  @override
  Future<Result<bool, RwGitException>> push(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) async {
    return Failure(RwGitException(message: 'LibGit2 push not implemented yet'));
  }

  @override
  Future<Result<String, RwGitException>> diff(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) async {
    return Failure(RwGitException(message: 'LibGit2 diff not implemented yet'));
  }

  @override
  Future<Result<bool, RwGitException>> merge(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) async {
    return Failure(
        RwGitException(message: 'LibGit2 merge not implemented yet'));
  }

  @override
  Future<Result<bool, RwGitException>> stash(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) async {
    return Failure(
        RwGitException(message: 'LibGit2 stash not implemented yet'));
  }

  @override
  Future<Result<String, RwGitException>> blame(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) async {
    return Failure(
        RwGitException(message: 'LibGit2 blame not implemented yet'));
  }

  @override
  Future<Result<String, RwGitException>> show(String directory,
      {List<String> extraArgs = const [], bool streamOutput = false}) async {
    return Failure(RwGitException(message: 'LibGit2 show not implemented yet'));
  }

  @override
  Future<Result<String, RwGitException>> runCommand(
      String directory, List<String> args,
      {bool streamOutput = false}) async {
    final runner = ProcessRunner.defaultRunner();
    final result = await runner.run('git', args,
        workingDirectory: directory, streamOutput: streamOutput);
    evaluateProcessResult(result);
    return Success(result.stdout?.toString() ?? '');
  }
}
