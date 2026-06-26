// ignore_for_file: avoid_dynamic_calls, unnecessary_cast
import 'dart:convert';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

class MockCodeQualityTrackerWithAuthors implements CodeQualityTracker {
  @override
  ProcessRunner get runner => throw UnimplementedError();

  @override
  Future<List<String>> findSuspiciousCommits(
    String repository, {
    List<String> keywords = const [],
    String? limit,
  }) async {
    return ['commit1: fixme'];
  }

  @override
  Future<String> extractChangedComments(
    String directory, {
    String? limit,
  }) async {
    return '';
  }

  @override
  Future<List<String>> findMegaCommits(
    String repository, {
    int fileThreshold = 20,
    int lineThreshold = 500,
    String? limit,
  }) async {
    return ['commit3: 1000 lines'];
  }

  @override
  Future<ChurnMetricsDto> calculateChurn(
    String repository, {
    String? limit,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ChurnMetricsWithAuthorsDto> calculateChurnWithAuthors(
    String repository, {
    String? limit,
  }) async {
    return const ChurnMetricsWithAuthorsDto(
      totalCommits: 100,
      fileChurn: {
        'file1.dart': ContributionStats(
          total: 20,
          authors: {'Alice': 15, 'Bob': 5},
        ),
        'file2.dart': ContributionStats(
          total: 5,
          authors: {'Alice': 5},
        ),
        'file3.dart': ContributionStats(
          total: 25,
          authors: {'Alice': 25},
        ),
      },
      classChurn: {
        'MyClass': ContributionStats(
          total: 15,
          authors: {'Charlie': 15},
        ),
      },
      blockChurn: {
        'myMethod': ContributionStats(
          total: 10,
          authors: {'Alice': 10},
        ),
      },
    );
  }
}

class MockEmptyCodeQualityTrackerWithAuthors implements CodeQualityTracker {
  @override
  ProcessRunner get runner => throw UnimplementedError();

  @override
  Future<List<String>> findSuspiciousCommits(
    String repository, {
    List<String> keywords = const [],
    String? limit,
  }) async {
    return [];
  }

  @override
  Future<String> extractChangedComments(
    String directory, {
    String? limit,
  }) async {
    return '';
  }

  @override
  Future<List<String>> findMegaCommits(
    String repository, {
    int fileThreshold = 20,
    int lineThreshold = 500,
    String? limit,
  }) async {
    return [];
  }

  @override
  Future<ChurnMetricsDto> calculateChurn(
    String repository, {
    String? limit,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ChurnMetricsWithAuthorsDto> calculateChurnWithAuthors(
    String repository, {
    String? limit,
  }) async {
    return const ChurnMetricsWithAuthorsDto(
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
        'git',
        ['log', '-n', '10', '--shortstat', '--format=%H %s'],
        0,
        'abc123 mocked commit\n'
            ' 3 files changed, 50 insertions(+)',
        '',
      );
      mockRunner.setMockResult(
        'git',
        ['log', '-n', '10', '-p'],
        0,
        'mocked code diff output',
        '',
      );
    });

    test('has correct name and input schema', () {
      final tool = AnalyzeCodeQualityWithAuthorsTool(
        MockCodeQualityTrackerWithAuthors(),
        rwGit,
      );
      expect(
        tool.name,
        'analyze_code_quality_with_authors',
      );
      expect(
        tool.description,
        contains('author-level'),
      );
      expect(tool.inputSchema['type'], 'object');
      expect(
        (tool.inputSchema['required'] as List).contains('directory'),
        isTrue,
      );
    });

    test(
      'execute returns valid JSON with author data',
      () async {
        final tool = AnalyzeCodeQualityWithAuthorsTool(
          MockCodeQualityTrackerWithAuthors(),
          rwGit,
        );
        final resultStr = await tool.execute({
          'directory': '/test/dir',
          'includeCommitLog': true,
        });

        final result = jsonDecode(resultStr) as Map<String, dynamic>;

        // Suspicious commits present
        expect(
          result['suspicious_commits'],
          contains('commit1: fixme'),
        );

        // Mega commits present
        expect(
          result['mega_commits'],
          contains('commit3: 1000 lines'),
        );

        // Churn data with authors
        expect(result['total_commits'], 100);

        final highChurn = result['high_churn_files'] as List;

        // file1.dart (20 changes) should be present
        final file1 = highChurn.firstWhere(
          (f) => (f as Map<String, dynamic>)['file'] == 'file1.dart',
        ) as Map<String, dynamic>;
        expect(file1['changes'], 20);
        expect(
          (file1['authors'] as Map<String, dynamic>)['Alice'],
          15,
        );
        expect(
          (file1['authors'] as Map<String, dynamic>)['Bob'],
          5,
        );

        // file2.dart (5 changes) should NOT be present
        // (below 10% threshold)
        expect(
          highChurn.any(
            (f) => (f as Map<String, dynamic>)['file'] == 'file2.dart',
          ),
          isFalse,
        );

        // Classes with authors
        final classes = result['top_churned_classes'] as List;
        final myClass = classes.first as Map<String, dynamic>;
        expect(myClass['class'], 'MyClass');
        expect(
          (myClass['authors'] as Map<String, dynamic>)['Charlie'],
          15,
        );

        // Commit log included
        expect(result['commit_log'], contains('mocked'));

        // Analysis guidance with author-specific hint
        final hints = result['analysis_hints'] as List;
        expect(
          hints.any(
            (h) => (h as String).contains(
              'knowledge silos',
            ),
          ),
          isTrue,
        );

        // No persona in the output
        expect(
          resultStr,
          isNot(contains('Staff Software Engineer')),
        );
      },
    );

    test('execute handles empty data correctly', () async {
      final tool = AnalyzeCodeQualityWithAuthorsTool(
        MockEmptyCodeQualityTrackerWithAuthors(),
        rwGit,
      );
      final resultStr = await tool.execute({'directory': '/test/dir'});

      final result = jsonDecode(resultStr) as Map<String, dynamic>;

      expect(result['suspicious_commits'], isEmpty);
      expect(result['mega_commits'], isEmpty);
      expect(result['total_commits'], 0);
      expect(result['high_churn_files'], isEmpty);
      expect(result['top_churned_classes'], isEmpty);
      expect(result['top_churned_blocks'], isEmpty);
    });

    test(
      'execute respects includeCommitLog and topN',
      () async {
        final tool = AnalyzeCodeQualityWithAuthorsTool(
          MockCodeQualityTrackerWithAuthors(),
          rwGit,
        );
        final resultStr = await tool.execute({
          'directory': '/test/dir',
          'includeCommitLog': false,
          'topN': 1,
        });

        final result = jsonDecode(resultStr) as Map<String, dynamic>;

        // No commit log
        expect(result.containsKey('commit_log'), isFalse);

        // topN = 1: only 1 suspicious commit
        expect(
          (result['suspicious_commits'] as List).length,
          1,
        );

        // topN = 1: only 1 high churn file
        expect(
          (result['high_churn_files'] as List).length,
          1,
        );
      },
    );

    test('execute respects includeCodeDiff', () async {
      final tool = AnalyzeCodeQualityWithAuthorsTool(
        MockCodeQualityTrackerWithAuthors(),
        rwGit,
      );
      final resultStr = await tool.execute({
        'directory': '/test/dir',
        'includeCodeDiff': true,
      });

      final result = jsonDecode(resultStr) as Map<String, dynamic>;

      // Code diff included
      expect(result['code_diff'], contains('mocked code diff'));

      // Analysis guidance includes code smells hint
      final hints = result['analysis_hints'] as List;
      expect(
        hints.any(
          (h) => (h as String).contains('obvious code smells'),
        ),
        isTrue,
      );
    });
  });
}
