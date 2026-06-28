// ignore_for_file: avoid_dynamic_calls, unnecessary_cast
import 'dart:convert';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

class MockCodeQualityTracker implements CodeQualityTracker {
  @override
  ProcessRunner get runner => throw UnimplementedError();

  @override
  Future<List<String>> findSuspiciousCommits(
    String repository, {
    List<String> keywords = const [],
    String? limit,
    String? since,
  }) async {
    return ['commit1: fixme', 'commit2: todo'];
  }

  @override
  Future<List<Map<String, dynamic>>> extractChangedComments(
    String directory, {
    String? limit,
    String? since,
  }) async {
    return [];
  }

  @override
  Future<List<String>> findMegaCommits(
    String repository, {
    int fileThreshold = 20,
    int lineThreshold = 500,
    String? limit,
    String? since,
  }) async {
    return ['commit3: 1000 lines'];
  }

  @override
  Future<List<String>> findSecrets(
    String directory, {
    String? limit,
    String? branch,
  }) async {
    return ['commit4: Found Potential Secret: AKIA***'];
  }

  @override
  Future<ChurnMetricsDto> calculateChurn(
    String repository, {
    String? limit,
    String? since,
  }) async {
    return const ChurnMetricsDto(
      totalCommits: 100,
      fileChurn: {
        'file1.dart': 20,
        'file2.dart': 5,
        'file3.dart': 25,
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
    String repository, {
    String? limit,
    String? since,
  }) async {
    throw UnimplementedError();
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

class MockEmptyCodeQualityTracker implements CodeQualityTracker {
  @override
  ProcessRunner get runner => throw UnimplementedError();

  @override
  Future<List<String>> findSuspiciousCommits(
    String repository, {
    List<String> keywords = const [],
    String? limit,
    String? since,
  }) async {
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> extractChangedComments(
    String directory, {
    String? limit,
    String? since,
  }) async {
    return [];
  }

  @override
  Future<List<String>> findMegaCommits(
    String repository, {
    int fileThreshold = 20,
    int lineThreshold = 500,
    String? limit,
    String? since,
  }) async {
    return [];
  }

  @override
  Future<List<String>> findSecrets(
    String directory, {
    String? limit,
    String? branch,
  }) async {
    return [];
  }

  @override
  Future<ChurnMetricsDto> calculateChurn(
    String repository, {
    String? limit,
    String? since,
  }) async {
    return const ChurnMetricsDto(
      totalCommits: 0,
      fileChurn: {},
      classChurn: {},
      blockChurn: {},
    );
  }

  @override
  Future<ChurnMetricsWithAuthorsDto> calculateChurnWithAuthors(
    String repository, {
    String? limit,
    String? since,
  }) async {
    throw UnimplementedError();
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
  group('AnalyzeCodeQualityTool', () {
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
      final tool = AnalyzeCodeQualityTool(
        MockCodeQualityTracker(),
        rwGit,
      );
      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema.isNotEmpty, isTrue);
      expect(tool.name, 'analyze_code_quality');
      expect(
        tool.description,
        contains('architectural'),
      );
      expect(tool.inputSchema['type'], 'object');
      expect(
        (tool.inputSchema['required'] as List).contains('directory'),
        isTrue,
      );
    });

    test('execute returns valid JSON with data', () async {
      final tool = AnalyzeCodeQualityTool(
        MockCodeQualityTracker(),
        rwGit,
      );
      final resultStr = await tool.execute({
        'directory': '/test/dir',
        'includeCommitLog': true,
      });

      final result = jsonDecode(resultStr) as Map<String, dynamic>;

      // Suspicious commits present
      final suspicious = result['suspicious_commits'] as List;
      expect(suspicious, contains('commit1: fixme'));
      expect(suspicious, contains('commit2: todo'));

      // Mega commits present
      final mega = result['mega_commits'] as List;
      expect(mega, contains('commit3: 1000 lines'));

      // Churn data present
      expect(result['total_commits'], 100);
      final highChurn = result['high_churn_files'] as List;
      // file1.dart (20) and file3.dart (25) are > 10%
      // of 100. file2.dart (5) is not.
      expect(
        highChurn.any(
          (f) => (f as Map<String, dynamic>)['file'] == 'file1.dart',
        ),
        isTrue,
      );
      expect(
        highChurn.any(
          (f) => (f as Map<String, dynamic>)['file'] == 'file2.dart',
        ),
        isFalse,
      );

      // Classes and blocks
      final classes = result['top_churned_classes'] as List;
      expect(
        classes.any(
          (c) => (c as Map<String, dynamic>)['class'] == 'MyClass',
        ),
        isTrue,
      );

      final blocks = result['top_churned_blocks'] as List;
      expect(
        blocks.any(
          (b) => (b as Map<String, dynamic>)['block'] == 'myMethod',
        ),
        isTrue,
      );

      // Commit log included
      expect(result['commit_log'], contains('mocked'));

      // Analysis guidance present
      expect(result['analysis_hints'], isA<List>());

      // No persona in the output
      expect(
        resultStr,
        isNot(contains('Staff Software Engineer')),
      );
    });

    test('execute handles empty data correctly', () async {
      final tool = AnalyzeCodeQualityTool(
        MockEmptyCodeQualityTracker(),
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
        final tool = AnalyzeCodeQualityTool(
          MockCodeQualityTracker(),
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
        final suspicious = result['suspicious_commits'] as List;
        expect(suspicious.length, 1);
        expect(suspicious.first, 'commit1: fixme');

        // topN = 1: only 1 high churn file
        final highChurn = result['high_churn_files'] as List;
        expect(highChurn.length, 1);

        // topN = 1: only 1 class and 1 block
        expect(
          (result['top_churned_classes'] as List).length,
          1,
        );
        expect(
          (result['top_churned_blocks'] as List).length,
          1,
        );
      },
    );

    test('execute respects includeCodeDiff', () async {
      final tool = AnalyzeCodeQualityTool(
        MockCodeQualityTracker(),
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
