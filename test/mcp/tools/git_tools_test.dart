import 'package:test/test.dart';
import 'package:rw_git/rw_git.dart';

class MockRwGit implements RwGit {
  @override
  String get invalidGitCommandResult => 'INVALID';

  @override
  String get gitRepoIndicator => '.git';

  @override
  Future<bool> init(String directoryToInit,
          {bool streamOutput = false}) async =>
      true;
  @override
  Future<bool> isGitRepository(String directoryToCheck,
          {bool streamOutput = false}) async =>
      true;
  @override
  Future<bool> clone(String localDirectoryToCloneInto, String repository,
          {bool streamOutput = false}) async =>
      true;
  @override
  Future<bool> checkout(String localCheckoutDirectory, String branchToCheckout,
          {bool streamOutput = false}) async =>
      true;
  @override
  Future<List<String>> fetchTags(String localCheckoutDirectory,
          {bool streamOutput = false}) async =>
      ['v1.0.0'];
  @override
  Future<List<String>> getCommitsBetween(
          String localCheckoutDirectory, String firstTag, String secondTag,
          {bool streamOutput = false}) async =>
      ['commit1', 'commit2'];
  @override
  Future<ShortStatDto> stats(
          String localCheckoutDirectory, String oldTag, String newTag,
          {bool streamOutput = false}) async =>
      ShortStatDto(1, 2, 3);
  @override
  Future<List<ShortLogDto>> contributionsByAuthor(String localCheckoutDirectory,
          {bool streamOutput = false}) async =>
      [ShortLogDto(10, 'Author')];
  @override
  Future<String> runCommand(String directory, List<String> args,
          {bool streamOutput = false}) async =>
      'command output';
  @override
  Future<bool> cloneSpecificBranch(String localDirectoryToCloneInto,
          String repository, String branchToCheckout,
          {bool streamOutput = false}) async =>
      true;
  @override
  Future<ShortStatDto> cloneAndGetStatistics(String localDirectoryToCloneInto,
          String repository, String oldTag, String newTag,
          {bool streamOutput = false}) async =>
      ShortStatDto(1, 2, 3);
}

void main() {
  late MockRwGit rwGit;

  setUp(() {
    rwGit = MockRwGit();
  });

  test('InitRepositoryTool', () async {
    final tool = InitRepositoryTool(rwGit);
    final result = await tool.execute({'directoryToInit': 'testDir'});
    expect(result, contains('true'));
  });

  test('IsGitRepositoryTool', () async {
    final tool = IsGitRepositoryTool(rwGit);
    final result = await tool.execute({'directoryToCheck': 'testDir'});
    expect(result, contains('true'));
  });

  test('CloneRepositoryTool', () async {
    final tool = CloneRepositoryTool(rwGit);
    final result = await tool
        .execute({'localDirectoryToCloneInto': 'testDir', 'repository': 'url'});
    expect(result, contains('true'));
  });

  test('CheckoutBranchTool', () async {
    final tool = CheckoutBranchTool(rwGit);
    final result = await tool.execute(
        {'localCheckoutDirectory': 'testDir', 'branchToCheckout': 'main'});
    expect(result, contains('true'));
  });

  test('FetchTagsTool', () async {
    final tool = FetchTagsTool(rwGit);
    final result = await tool.execute({'localCheckoutDirectory': 'testDir'});
    expect(result, contains('v1.0.0'));
  });

  test('GetCommitsBetweenTool', () async {
    final tool = GetCommitsBetweenTool(rwGit);
    final result = await tool.execute({
      'localCheckoutDirectory': 'testDir',
      'firstTag': 'v1',
      'secondTag': 'v2'
    });
    expect(result, contains('commit1'));
  });

  test('GetStatsTool', () async {
    final tool = GetStatsTool(rwGit);
    final result = await tool.execute(
        {'localCheckoutDirectory': 'testDir', 'oldTag': 'v1', 'newTag': 'v2'});
    expect(result, contains('1'));
  });

  test('GetContributionsByAuthorTool', () async {
    final tool = GetContributionsByAuthorTool(rwGit);
    final result = await tool.execute({'localCheckoutDirectory': 'testDir'});
    expect(result, contains('Author'));
  });

  test('CloneSpecificBranchTool', () async {
    final tool = CloneSpecificBranchTool(rwGit);
    final result = await tool.execute({
      'localDirectoryToCloneInto': 'testDir',
      'repository': 'url',
      'branchToCheckout': 'main'
    });
    expect(result, contains('true'));
  });

  test('CloneAndGetStatisticsTool', () async {
    final tool = CloneAndGetStatisticsTool(rwGit);
    final result = await tool.execute({
      'localDirectoryToCloneInto': 'testDir',
      'repository': 'url',
      'oldTag': 'v1',
      'newTag': 'v2'
    });
    expect(result, contains('1'));
  });

  test('GetRwGitDocumentationTool', () async {
    final tool = GetRwGitDocumentationTool();
    final result = await tool.execute({});
    expect(result, isNotEmpty);
  });
}
