import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

class MockCodeQualityTrackerWithAuthors implements CodeQualityTracker {
  @override
  ProcessRunner get runner => throw UnimplementedError();

  @override
  Future<List<String>> findSuspiciousCommits(String repository,
      {List<String> keywords = const [], String? limit}) async {
    return ['commit1: fixme'];
  }

  @override
  Future<String> extractChangedComments(String directory,
      {String? limit}) async {
    return '';
  }

  @override
  Future<List<String>> findMegaCommits(String repository,
      {int fileThreshold = 20, int lineThreshold = 500, String? limit}) async {
    return ['commit3: 1000 lines'];
  }

  @override
  Future<ChurnMetricsDto> calculateChurn(String repository,
      {String? limit}) async {
    throw UnimplementedError();
  }

  @override
  Future<ChurnMetricsWithAuthorsDto> calculateChurnWithAuthors(
      String repository,
      {String? limit}) async {
    return ChurnMetricsWithAuthorsDto(
      totalCommits: 100,
      fileChurn: {
        'file1.dart':
            ContributionStats(total: 20, authors: {'Alice': 15, 'Bob': 5}),
        'file2.dart': ContributionStats(total: 5, authors: {'Alice': 5}),
      },
      classChurn: {
        'MyClass': ContributionStats(total: 15, authors: {'Charlie': 15}),
      },
      blockChurn: {
        'myMethod': ContributionStats(total: 10, authors: {'Alice': 10}),
      },
    );
  }
}

class MockEmptyCodeQualityTrackerWithAuthors implements CodeQualityTracker {
  @override
  ProcessRunner get runner => throw UnimplementedError();

  @override
  Future<List<String>> findSuspiciousCommits(String repository,
      {List<String> keywords = const [], String? limit}) async {
    return [];
  }

  @override
  Future<String> extractChangedComments(String directory,
      {String? limit}) async {
    return '';
  }

  @override
  Future<List<String>> findMegaCommits(String repository,
      {int fileThreshold = 20, int lineThreshold = 500, String? limit}) async {
    return [];
  }

  @override
  Future<ChurnMetricsDto> calculateChurn(String repository,
      {String? limit}) async {
    throw UnimplementedError();
  }

  @override
  Future<ChurnMetricsWithAuthorsDto> calculateChurnWithAuthors(
      String repository,
      {String? limit}) async {
    return ChurnMetricsWithAuthorsDto(
      totalCommits: 0,
      fileChurn: {},
      classChurn: {},
      blockChurn: {},
    );
  }
}

void main() {
  group('AnalyzeCodeQualityWithAuthorsTool', () {
    late MockProcessRunner mockRunner;
    late RwGit rwGit;

    setUp(() {
      mockRunner = MockProcessRunner();
      rwGit = RwGit(runner: mockRunner);
      mockRunner.setMockResult(
          'git', ['log', '-n', '10', '--stat'], 0, 'mocked commit log', '');
    });

    test('has correct name and input schema', () {
      final tool = AnalyzeCodeQualityWithAuthorsTool(
          MockCodeQualityTrackerWithAuthors(), rwGit);
      expect(tool.name, 'analyze_code_quality_with_authors');
      expect(
          tool.description, contains('breakdown of which authors contributed'));
      expect(tool.inputSchema['type'], 'object');
      expect(
          (tool.inputSchema['required'] as List).contains('directory'), isTrue);
    });

    test('execute formats results correctly with data and authors', () async {
      final tool = AnalyzeCodeQualityWithAuthorsTool(
          MockCodeQualityTrackerWithAuthors(), rwGit);
      final result =
          await tool.execute({'directory': '/test/dir', 'includeRawLog': true});

      expect(result, contains('commit1: fixme'));
      expect(result, contains('commit3: 1000 lines'));

      expect(result, contains('- file1.dart: 20 changes'));
      expect(result, contains('* Alice: 15'));
      expect(result, contains('* Bob: 5'));

      expect(result, isNot(contains('file2.dart')));

      expect(result, contains('- MyClass: 15 changes'));
      expect(result, contains('* Charlie: 15'));

      expect(result, contains('- myMethod: 10 changes'));
      expect(result, contains('You are a Staff Software Engineer.'));
      expect(result, contains('mocked commit log'));
    });

    test('execute handles empty data correctly', () async {
      final tool = AnalyzeCodeQualityWithAuthorsTool(
          MockEmptyCodeQualityTrackerWithAuthors(), rwGit);
      final result = await tool.execute({'directory': '/test/dir'});

      expect(result,
          contains('Suspicious Commits (fixme/todo/temporary):\nNone found.'));
      expect(
          result,
          contains(
              'Mega Commits (>500 lines changed or >20 files):\nNone found.'));
      expect(
          result,
          contains(
              'High Churn Files (modified in >10% of commits, total commits: 0):\nNone found.'));
      expect(result, contains('Top Churned Classes:\nNone found.'));
      expect(result, contains('Top Churned Blocks/Methods:\nNone found.'));
    });
    test('execute respects includeRawLog and topN', () async {
      final tool = AnalyzeCodeQualityWithAuthorsTool(
          MockCodeQualityTrackerWithAuthors(), rwGit);
      final result = await tool.execute({
        'directory': '/test/dir',
        'includeRawLog': false,
        'topN': 1,
      });

      expect(result, isNot(contains('mocked commit log')));
      expect(result, contains('commit1: fixme'));
      expect(result, contains('commit3: 1000 lines'));
    });
  });
}
