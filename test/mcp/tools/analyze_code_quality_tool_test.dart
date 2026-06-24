import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

class MockCodeQualityTracker implements CodeQualityTracker {
  @override
  ProcessRunner get runner => throw UnimplementedError();

  @override
  Future<List<String>> findSuspiciousCommits(String repository,
      {List<String> keywords = const []}) async {
    return ['commit1: fixme', 'commit2: todo'];
  }

  @override
  Future<List<String>> findMegaCommits(String repository,
      {int fileThreshold = 20, int lineThreshold = 500}) async {
    return ['commit3: 1000 lines'];
  }

  @override
  Future<ChurnMetricsDto> calculateChurn(String repository) async {
    return ChurnMetricsDto(
      totalCommits: 100,
      fileChurn: {
        'file1.dart': 20,
        'file2.dart': 5,
      },
      classChurn: {
        'MyClass': 15,
      },
      blockChurn: {
        'myMethod': 10,
      },
    );
  }

  @override
  Future<ChurnMetricsWithAuthorsDto> calculateChurnWithAuthors(
      String repository) async {
    throw UnimplementedError();
  }
}

class MockEmptyCodeQualityTracker implements CodeQualityTracker {
  @override
  ProcessRunner get runner => throw UnimplementedError();

  @override
  Future<List<String>> findSuspiciousCommits(String repository,
      {List<String> keywords = const []}) async {
    return [];
  }

  @override
  Future<List<String>> findMegaCommits(String repository,
      {int fileThreshold = 20, int lineThreshold = 500}) async {
    return [];
  }

  @override
  Future<ChurnMetricsDto> calculateChurn(String repository) async {
    return ChurnMetricsDto(
      totalCommits: 0,
      fileChurn: {},
      classChurn: {},
      blockChurn: {},
    );
  }

  @override
  Future<ChurnMetricsWithAuthorsDto> calculateChurnWithAuthors(
      String repository) async {
    throw UnimplementedError();
  }
}

void main() {
  group('AnalyzeCodeQualityTool', () {
    test('has correct name and input schema', () {
      final tool = AnalyzeCodeQualityTool(MockCodeQualityTracker());
      expect(tool.name, 'analyze_code_quality');
      expect(tool.description, contains('surface architectural bottlenecks'));
      expect(tool.inputSchema['type'], 'object');
      expect(
          (tool.inputSchema['required'] as List).contains('directory'), isTrue);
    });

    test('execute formats results correctly with data', () async {
      final tool = AnalyzeCodeQualityTool(MockCodeQualityTracker());
      final result = await tool.execute({'directory': '/test/dir'});

      expect(result, contains('commit1: fixme'));
      expect(result, contains('commit2: todo'));
      expect(result, contains('commit3: 1000 lines'));
      // file1.dart has 20 changes > 10% of 100
      expect(result, contains('- file1.dart: 20 changes'));
      // file2.dart has 5 changes < 10% of 100, so it shouldn't be high churn
      expect(result, isNot(contains('file2.dart')));
      expect(result, contains('- MyClass: 15 changes'));
      expect(result, contains('- myMethod: 10 changes'));
    });

    test('execute handles empty data correctly', () async {
      final tool = AnalyzeCodeQualityTool(MockEmptyCodeQualityTracker());
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
  });
}
