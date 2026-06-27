// ignore_for_file: avoid_dynamic_calls
import 'dart:convert';
import 'package:rw_git/rw_git.dart';
import 'package:rw_git/src/core/result.dart';
import 'package:rw_git/src/mcp/tools/analyze_file_ownership_tool.dart';
import 'package:test/test.dart';

class _MockRwGit implements RwGit {
  final String codeownersContent;
  final bool codeownersExists;

  _MockRwGit({
    this.codeownersContent = '',
    this.codeownersExists = false,
  });

  @override
  String get invalidGitCommandResult => 'INVALID';
  @override
  String get gitRepoIndicator => '.git';

  @override
  Future<Result<String, RwGitException>> runCommand(
    String directory,
    List<String> args, {
    bool streamOutput = false,
  }) async {
    if (args.contains('show')) {
      if (codeownersExists) {
        return Success(codeownersContent);
      }
      return Failure(RwGitException(
        message: 'not found',
        exitCode: 128,
        stderr: 'does not exist',
      ));
    }
    return const Success('');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _MockTracker implements CodeQualityTracker {
  @override
  ProcessRunner get runner => throw UnimplementedError();

  @override
  Future<ChurnMetricsWithAuthorsDto> calculateChurnWithAuthors(
    String repository, {
    String? limit,
  }) async {
    return const ChurnMetricsWithAuthorsDto(
      totalCommits: 50,
      fileChurn: {
        'lib/main.dart': ContributionStats(
          total: 20,
          authors: {'Alice': 15, 'Bob': 5},
        ),
        'lib/utils.dart': ContributionStats(
          total: 10,
          authors: {'Carol': 10},
        ),
      },
      classChurn: {},
      blockChurn: {},
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  group('AnalyzeFileOwnershipTool', () {
    test('has correct name and schema', () {
      final tracker = _MockTracker();
      final rwGit = _MockRwGit();
      final tool = AnalyzeFileOwnershipTool(tracker, rwGit);

      expect(tool.name, 'analyze_file_ownership');
      expect(tool.inputSchema['required'], contains('directory'));
    });

    test('detects ownership drift with CODEOWNERS', () async {
      final codeowners = '''
# CODEOWNERS
*.dart @bob
lib/utils.dart @alice
''';

      final tracker = _MockTracker();
      final rwGit = _MockRwGit(
        codeownersContent: codeowners,
        codeownersExists: true,
      );
      final tool = AnalyzeFileOwnershipTool(tracker, rwGit);

      final result = await tool.execute({'directory': '/test'});
      final parsed = jsonDecode(result) as Map<String, dynamic>;

      expect(parsed['codeowners_found'], isTrue);
      expect(parsed['total_files_analyzed'], 2);
      // lib/utils.dart owned by @alice but Carol is
      // the top contributor, so drift = true
      final files = parsed['files'] as List;
      final utilsFile = files.firstWhere(
        (f) => f['file'] == 'lib/utils.dart',
      );
      expect(utilsFile['ownership_drift'], isTrue);
    });

    test('handles missing CODEOWNERS', () async {
      final tracker = _MockTracker();
      final rwGit = _MockRwGit(codeownersExists: false);
      final tool = AnalyzeFileOwnershipTool(tracker, rwGit);

      final result = await tool.execute({'directory': '/test'});
      final parsed = jsonDecode(result) as Map<String, dynamic>;

      expect(parsed['codeowners_found'], isFalse);
      expect(parsed['total_files_analyzed'], 2);
    });
  });
}
