// ignore_for_file: avoid_dynamic_calls, unnecessary_cast
import 'package:test/test.dart';
import 'package:rw_git/rw_git.dart';
import 'package:rw_git/src/core/result.dart';
import 'package:rw_git/src/vcs/git_query.dart';

class MockGitQuery implements GitQuery {
  @override
  Future<Result<String, RwGitException>> run(
          String directory, List<String> args) async =>
      const Success('command output');
}

class MockRwGit implements RwGit {
  @override
  String get invalidGitCommandResult => 'INVALID';

  @override
  String get gitRepoIndicator => '.git';

  @override
  Future<Result<bool, RwGitException>> init(String directoryToInit,
          {bool streamOutput = false}) async =>
      const Success(true);
  @override
  Future<Result<bool, RwGitException>> isGitRepository(String directoryToCheck,
          {bool streamOutput = false}) async =>
      const Success(true);
  @override
  Future<Result<bool, RwGitException>> clone(
          String localDirectoryToCloneInto, String repository,
          {bool streamOutput = false}) async =>
      const Success(true);
  @override
  Future<Result<bool, RwGitException>> checkout(
          String localCheckoutDirectory, String branchToCheckout,
          {bool streamOutput = false}) async =>
      const Success(true);
  @override
  Future<Result<List<GitTag>, RwGitException>> fetchTags(
          String localCheckoutDirectory,
          {bool streamOutput = false}) async =>
      const Success([GitTag(name: 'v1.0.0')]);
  @override
  Future<Result<List<GitCommit>, RwGitException>> getCommitsBetween(
          String localCheckoutDirectory, String firstTag, String secondTag,
          {bool streamOutput = false}) async =>
      const Success([
        GitCommit(
            hash: 'hash1',
            authorName: 'A',
            authorEmail: 'B',
            date: 'C',
            message: 'commit1'),
        GitCommit(
            hash: 'hash2',
            authorName: 'A',
            authorEmail: 'B',
            date: 'C',
            message: 'commit2')
      ]);
  @override
  Future<Result<ShortStatDto, RwGitException>> stats(
          String localCheckoutDirectory, String oldTag, String newTag,
          {bool streamOutput = false}) async =>
      const Success(ShortStatDto(1, 2, 3));
  @override
  Future<Result<List<ShortLogDto>, RwGitException>> contributionsByAuthor(
          String localCheckoutDirectory,
          {bool streamOutput = false}) async =>
      const Success([ShortLogDto(10, 'Author')]);
  @override
  Future<Result<List<GitBranch>, RwGitException>> branch(String directory,
          {List<String> extraArgs = const [],
          bool streamOutput = false}) async =>
      const Success([]);
  @override
  Future<Result<GitStatus, RwGitException>> status(String directory,
          {List<String> extraArgs = const [],
          bool streamOutput = false}) async =>
      const Success(GitStatus());
  @override
  Future<Result<bool, RwGitException>> pull(String directory,
          {List<String> extraArgs = const [],
          bool streamOutput = false}) async =>
      const Success(true);
  @override
  Future<Result<GitDiff, RwGitException>> diff(String directory,
          {List<String> extraArgs = const [],
          bool streamOutput = false}) async =>
      const Success(GitDiff());
  @override
  Future<Result<bool, RwGitException>> merge(String directory,
          {List<String> extraArgs = const [],
          bool streamOutput = false}) async =>
      const Success(true);
  @override
  Future<Result<bool, RwGitException>> stash(String directory,
          {List<String> extraArgs = const [],
          bool streamOutput = false}) async =>
      const Success(true);
  @override
  Future<Result<GitBlame, RwGitException>> blame(String directory,
          {List<String> extraArgs = const [],
          bool streamOutput = false}) async =>
      const Success(GitBlame());
  @override
  Future<Result<GitCommit, RwGitException>> show(String directory,
          {List<String> extraArgs = const [],
          bool streamOutput = false}) async =>
      const Success(GitCommit(
          hash: 'h',
          authorName: 'n',
          authorEmail: 'e',
          date: 'd',
          message: 'm'));

  @override
  Future<Result<bool, RwGitException>> cloneSpecificBranch(
          String localDirectoryToCloneInto,
          String repository,
          String branchToCheckout,
          {bool streamOutput = false}) async =>
      const Success(true);
}

void main() {
  late MockRwGit rwGit;

  setUp(() {
    rwGit = MockRwGit();
  });

  test('InitRepositoryTool', () async {
    final tool = InitRepositoryTool(rwGit);
    final result = await tool.execute({'directory': 'testDir'});
    expect(result, contains('true'));
  });

  test('IsGitRepositoryTool', () async {
    final tool = IsGitRepositoryTool(rwGit, MockGitQuery());
    final result = await tool.execute({'directory': 'testDir'});
    expect(result, contains('true'));
  });

  test('CloneRepositoryTool', () async {
    final tool = CloneRepositoryTool(rwGit);
    final result =
        await tool.execute({'directory': 'testDir', 'repository': 'url'});
    expect(result, contains('true'));
  });

  test('CheckoutBranchTool', () async {
    final tool = CheckoutBranchTool(rwGit);
    final result = await tool
        .execute({'directory': 'testDir', 'branchToCheckout': 'main'});
    expect(result, contains('true'));
  });

  test('FetchTagsTool', () async {
    final tool = FetchTagsTool(rwGit);
    final result = await tool.execute({'directory': 'testDir'});
    expect(result, contains('v1.0.0'));
  });

  test('GetCommitsBetweenTool', () async {
    final tool = GetCommitsBetweenTool(rwGit);
    final result = await tool
        .execute({'directory': 'testDir', 'firstTag': 'v1', 'secondTag': 'v2'});
    expect(result, contains('commit1'));
  });

  test('GetStatsTool', () async {
    final tool = GetStatsTool(rwGit, MockGitQuery());
    final result = await tool
        .execute({'directory': 'testDir', 'oldTag': 'v1', 'newTag': 'v2'});
    expect(result, contains('1'));
  });

  test('GetContributionsByAuthorTool', () async {
    final tool = GetContributionsByAuthorTool(rwGit);
    final result = await tool.execute({'directory': 'testDir'});
    expect(result, contains('Author'));
  });

  test('CloneSpecificBranchTool', () async {
    final tool = CloneSpecificBranchTool(rwGit);
    final result = await tool.execute({
      'directory': 'testDir',
      'repository': 'url',
      'branchToCheckout': 'main'
    });
    expect(result, contains('true'));
  });

  test('GetRwGitDocumentationTool', () async {
    final tool = GetRwGitDocumentationTool(McpRegistry());
    final result = await tool.execute({});
    expect(result, isNotEmpty);
  });
}
