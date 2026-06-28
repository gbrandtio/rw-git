// ignore_for_file: avoid_dynamic_calls, unnecessary_cast
import 'dart:convert';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

class MockCodeQualityTrackerForBusFactor implements CodeQualityTracker {
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
  Future<ChurnMetricsWithAuthorsDto> calculateChurnWithAuthors(
      String repository,
      {String? limit}) async {
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
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  group('AnalyzeBusFactorTool', () {
    late RwGit rwGit;

    setUp(() {
      rwGit = RwGit(runner: MockProcessRunner());
    });

    test('has correct name and input schema', () {
      final tool =
          AnalyzeBusFactorTool(MockCodeQualityTrackerForBusFactor(), rwGit);
      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema.isNotEmpty, isTrue);
      expect(tool.name, 'analyze_bus_factor');
      expect(
          (tool.inputSchema['required'] as List).contains('directory'), isTrue);
    });

    test('execute filters high risk files correctly', () async {
      final tool =
          AnalyzeBusFactorTool(MockCodeQualityTrackerForBusFactor(), rwGit);
      final resultRaw = await tool.execute({'directory': '/test/dir'});
      final result = jsonDecode(resultRaw) as Map<String, dynamic>;

      expect(result['total_commits_analyzed'], 100);
      expect(result.containsKey('high_risk_files'), isTrue);
      expect(result.containsKey('all_files'), isFalse);

      final files = result['high_risk_files'] as List;
      expect(files.length, 2);
      expect(files[0]['file'], 'high_risk_2.dart'); // 12 changes vs 10
      expect(files[0]['top_author'], 'Alice');
    });

    test('execute returns all files when detailed is true', () async {
      final tool =
          AnalyzeBusFactorTool(MockCodeQualityTrackerForBusFactor(), rwGit);
      final resultRaw =
          await tool.execute({'directory': '/test/dir', 'detailed': true});
      final result = jsonDecode(resultRaw) as Map<String, dynamic>;

      expect(result.containsKey('high_risk_files'), isFalse);
      expect(result.containsKey('all_files'), isTrue);

      final files = result['all_files'] as List;
      expect(files.length, 4); // high_risk, low_risk, ignored
    });
  });
}
