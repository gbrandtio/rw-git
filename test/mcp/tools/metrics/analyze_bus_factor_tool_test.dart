// ignore_for_file: avoid_dynamic_calls, unnecessary_cast
import 'dart:convert';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

class MockCodeQualityTrackerForBusFactor implements CodeQualityTracker {
  final ProcessRunner _runner;

  MockCodeQualityTrackerForBusFactor(this._runner);

  @override
  ProcessRunner get runner => _runner;

  @override
  Future<List<String>> findSuspiciousCommits(String repository,
      {List<String> keywords = const [], String? limit}) async {
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> extractChangedComments(String directory,
      {String? limit}) async {
    return [];
  }

  @override
  Future<List<String>> findMegaCommits(String repository,
      {int fileThreshold = 20, int lineThreshold = 500, String? limit}) async {
    return [];
  }

  @override
  Future<List<String>> findSecrets(String directory,
      {String? limit, String? branch}) async {
    return [];
  }

  @override
  Future<ChurnMetricsDto> calculateChurn(String repository,
      {String? limit}) async {
    throw UnimplementedError();
  }

  @override
  Future<ChurnMetricsWithAuthorsDto> calculateChurnWithAuthors(String directory,
      {String? limit, String? since}) async {
    return const ChurnMetricsWithAuthorsDto(
      totalCommits: 100,
      fileChurn: {
        'high_risk.dart': ContributionStats(
          total: 10,
          authors: {'Alice': 9, 'Bob': 1}, // 90% Alice
        ),
        'high_risk_2.dart': ContributionStats(
          total: 12,
          authors: {'Alice': 11, 'Bob': 1}, // 90% Alice
        ),
        'low_risk.dart': ContributionStats(
          total: 20,
          authors: {'Alice': 10, 'Bob': 10}, // 50% Alice
        ),
        'ignored.dart': ContributionStats(
          total: 2, // Too few changes
          authors: {'Bob': 2}, // 100% Bob, but < 5 changes
        ),
      },
      classChurn: {
        'ClassA': ContributionStats(total: 10, authors: {}),
        'ClassB': ContributionStats(total: 5, authors: {}),
      },
      blockChurn: {
        'BlockA': ContributionStats(total: 10, authors: {}),
        'BlockB': ContributionStats(total: 5, authors: {}),
      },
    );
  }

  @override
  @override
  Future<AdvancedCodeQualityDto> calculateAdvancedMetrics(String directory,
      {String? limit}) async {
    return AdvancedCodeQualityDto(
      fileComplexity: {},
      coChangeMatrix: {},
      methodChurn: {},
      architectureDistribution: {},
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  group('AnalyzeBusFactorTool', () {
    late RwGit rwGit;
    late MockProcessRunner mockRunner;

    setUp(() {
      mockRunner = MockProcessRunner();
      mockRunner.setMockResult('git', ['log', '-n', '500', '--format=%an'], 0,
          'Alice\nBob\nAlice\nAlice\nCharlie\n', '');

      rwGit = RwGit(runner: mockRunner);
    });

    test('has correct name and input schema', () {
      final tool = AnalyzeBusFactorTool(
          MockCodeQualityTrackerForBusFactor(mockRunner), rwGit);
      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema.isNotEmpty, isTrue);
      expect(tool.name, 'analyze_bus_factor');
      expect(
          (tool.inputSchema['required'] as List).contains('directory'), isTrue);
    });

    test('execute calculates bus factor correctly', () async {
      final tool = AnalyzeBusFactorTool(
          MockCodeQualityTrackerForBusFactor(mockRunner), rwGit);
      final resultRaw = await tool.execute({'directory': '/test/dir'});
      final result = jsonDecode(resultRaw) as Map<String, dynamic>;

      expect(result['total_developers_analyzed'], 3); // Alice, Bob, Charlie
      expect(result['bus_factor'], 1); // Alice has 3/5 = 60%, threshold 50%
      expect(result.containsKey('top_contributors'), isTrue);

      final contributors = result['top_contributors'] as List;
      expect(contributors.length, 1);
      expect(contributors[0]['author'], 'Alice');
      expect(contributors[0]['contributions'], 3);
    });
  });
}
