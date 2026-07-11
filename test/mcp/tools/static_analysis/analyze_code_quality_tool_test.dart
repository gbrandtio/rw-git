import 'dart:convert';
import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:rw_git/src/core/result.dart';
import 'package:rw_git/src/vcs/git_query.dart';
import 'package:test/test.dart';

class _MockRunner implements ProcessRunner {
  final String churnOutput;
  final String megaOutput;
  final String suspiciousOutput;

  _MockRunner(this.churnOutput, this.megaOutput, this.suspiciousOutput);

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> args, {
    String? workingDirectory,
    bool streamOutput = false,
  }) async {
    if (args.contains('rev-list')) {
      return ProcessResult(0, 0, '10', '');
    }
    if (args.contains('--shortstat')) {
      return ProcessResult(0, 0, megaOutput, '');
    }
    return ProcessResult(0, 0, '', '');
  }

  @override
  Stream<String> runStream(
    String executable,
    List<String> args, {
    String? workingDirectory,
  }) async* {
    if (args.contains('-p') && args.contains('--format=%H||%an||%aI||%s')) {
      for (final line in suspiciousOutput.split('\n')) {
        yield line;
      }
    } else if (args.contains('--name-only') && args.contains('--format=')) {
      for (final line in churnOutput.split('\n')) {
        yield line;
      }
    }
  }
}

class _MockGitQuery implements GitQuery {
  const _MockGitQuery();

  @override
  Future<Result<String, RwGitException>> run(
    String directory,
    List<String> args,
  ) async {
    if (args.contains('log')) {
      if (args.contains('-p')) return const Success('mock diff');
      return const Success('mock log');
    }
    return const Success('');
  }
}

void main() {
  group('AnalyzeCodeQualityTool', () {
    test('has valid name and description', () {
      final runner = _MockRunner('', '', '');
      final tool = AnalyzeCodeQualityTool(runner, const _MockGitQuery());
      expect(tool.name, isNotEmpty);
      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema, isNotEmpty);
    });

    test('executes with mock data', () async {
      final churnSb = StringBuffer();
      for (int i = 0; i < 11; i++) {
        churnSb.writeln('file$i.dart');
        churnSb.writeln('file$i.dart');
      }

      final megaSb = StringBuffer();
      for (int i = 0; i < 15; i++) {
        megaSb.writeln('hash$i||author||date||Hack message');
        megaSb.writeln(
          ' 100 files changed, 2000 insertions(+), 10 deletions(-)',
        );
        megaSb.writeln('');
      }

      final suspiciousSb = StringBuffer();
      for (int i = 0; i < 15; i++) {
        suspiciousSb.writeln('hash$i||author||date||Hack message');
        suspiciousSb.writeln('--- a/file.dart');
        suspiciousSb.writeln('@@ -1 +1 @@ class Alpha { // hack');
      }

      final runner = _MockRunner(
        churnSb.toString(),
        megaSb.toString(),
        suspiciousSb.toString(),
      );
      final tool = AnalyzeCodeQualityTool(runner, const _MockGitQuery());

      final result = await tool.execute({
        'directory': './',
        'limit': 5,
        'topN': 5,
        'includeCommitLog': true,
        'includeCodeDiff': true,
      });
      final parsed = jsonDecode(result) as Map<String, dynamic>;

      expect(parsed, isNotNull);
      expect(parsed['high_churn_files'], isNotEmpty);
      expect(parsed['suspicious_commits'], isNotEmpty);
      expect(parsed['mega_commits'], isNotEmpty);
      expect(parsed['commit_log'], equals('mock log'));
      expect(parsed['code_diff'], equals('mock diff'));
    });

    test('executes with short lists and false flags', () async {
      final churnSb = StringBuffer();

      final megaSb = StringBuffer();
      megaSb.writeln('hash0||author||date||Hack message');
      megaSb.writeln(' 100 files changed, 2000 insertions(+), 10 deletions(-)');
      megaSb.writeln('');

      final suspiciousSb = StringBuffer();
      suspiciousSb.writeln('hash0||author||date||Hack message');
      suspiciousSb.writeln('--- a/file.dart');
      suspiciousSb.writeln('@@ -1 +1 @@ class Alpha { // hack');

      final runner = _MockRunner(
        churnSb.toString(),
        megaSb.toString(),
        suspiciousSb.toString(),
      );
      final tool = AnalyzeCodeQualityTool(runner, const _MockGitQuery());

      final result = await tool.execute({
        'directory': './',
        'limit': 5,
        'topN': 5,
        'includeCommitLog': false,
        'includeCodeDiff': false,
      });
      final parsed = jsonDecode(result) as Map<String, dynamic>;

      expect(parsed, isNotNull);
      expect(parsed.containsKey('commit_log'), isFalse);
      expect(parsed.containsKey('code_diff'), isFalse);
    });
  });
}
