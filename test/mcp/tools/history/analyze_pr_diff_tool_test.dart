// ignore_for_file: avoid_dynamic_calls
import 'dart:convert';
import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:rw_git/src/core/result.dart';
import 'package:test/test.dart';

class _MockRunner implements ProcessRunner {
  final Map<String, String> _results = {};

  void setResult(String executable, List<String> args, String out) {
    _results['$executable ${args.join(' ')}'] = out;
  }

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool streamOutput = false,
  }) async {
    final key = '$executable ${arguments.join(' ')}';
    for (final entry in _results.entries) {
      if (key.contains(entry.key) ||
          entry.key.contains(key.split(' ').take(3).join(' '))) {
        return ProcessResult(0, 0, entry.value, '');
      }
    }
    return ProcessResult(0, 0, '', '');
  }

  @override
  Stream<String> runStream(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async* {
    final key = '$executable ${arguments.join(' ')}';
    for (final entry in _results.entries) {
      if (key.contains(entry.key) ||
          entry.key.contains(key.split(' ').take(3).join(' '))) {
        for (final line in entry.value.split('\n')) {
          yield line;
        }
        return;
      }
    }
  }
}

class _MockRwGit implements RwGit {
  final String numstatOutput;
  final String logOutput;
  final String diffOutput;

  _MockRwGit({
    this.numstatOutput = '',
    this.logOutput = '',
    this.diffOutput = '',
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
    if (args.contains('--numstat') && args.contains('diff')) {
      return Success(numstatOutput);
    }
    if (args.contains('-p')) {
      return Success(logOutput);
    }
    if (args.contains('-U0')) {
      return Success(diffOutput);
    }
    return const Success('');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  group('AnalyzePrDiffTool', () {
    test('has correct name and schema', () {
      final runner = _MockRunner();
      final rwGit = _MockRwGit();
      final tool = AnalyzePrDiffTool(runner, rwGit);

      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema.isNotEmpty, isTrue);
      expect(tool.name, 'analyze_pr_diff');
      expect(tool.inputSchema['required'],
          containsAll(['directory', 'base', 'head']));
    });

    test('returns structured JSON with risk scores and secrets', () async {
      final runner = _MockRunner();
      runner.setResult('git', ['rev-list', '--count'], '100');
      // For churn heuristic
      runner.setResult('git', ['log', '-n'],
          'AUTHOR:Author One\n--- a/lib/src/main.dart\n@@ -1,1 +1,1 @@ class Main {\nAUTHOR:Author Two\n--- a/lib/src/main.dart\n@@ -2,2 +2,2 @@ class Main {\n');

      final numstat = '50\t10\tlib/src/main.dart\n5\t2\tREADME.md';
      final logOutput = '+++ b/lib/src/main.dart\n+ AKIAIOSFODNN7EXAMPLE\n';
      final diffOutput =
          '+++ b/lib/src/main.dart\n@@ -1,3 +1,3 @@ class Main {\n+ void main() {}\n';

      final rwGit = _MockRwGit(
        numstatOutput: numstat,
        logOutput: logOutput,
        diffOutput: diffOutput,
      );
      final tool = AnalyzePrDiffTool(runner, rwGit);

      final result = await tool.execute({
        'directory': '/test',
        'base': 'main',
        'head': 'feature',
      });

      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed.containsKey('total_files_changed'), isTrue);
      expect(parsed.containsKey('overall_risk_level'), isTrue);
      expect(parsed.containsKey('changed_files'), isTrue);

      final files = parsed['changed_files'] as List;
      final mainDart =
          files.firstWhere((f) => f['file'] == 'lib/src/main.dart');
      expect(mainDart['has_secret_exposure'], isTrue);
      expect(mainDart['hunks'], greaterThanOrEqualTo(1));
    });

    test('respects topN parameter', () async {
      final runner = _MockRunner();
      runner.setResult('git', ['rev-list', '--count'], '100');
      runner.setResult('git', ['log', '-n'],
          'AUTHOR:Author One\n--- a/file1.dart\n@@ -1,1 +1,1 @@ class Main {\n');

      final numstat =
          '10\t5\tfile1.dart\n20\t10\tfile2.dart\n30\t15\tfile3.dart';

      final rwGit = _MockRwGit(numstatOutput: numstat);
      final tool = AnalyzePrDiffTool(runner, rwGit);

      final result = await tool.execute({
        'directory': '/test',
        'base': 'main',
        'head': 'feature',
        'topN': 1,
      });

      final parsed = jsonDecode(result) as Map<String, dynamic>;
      final files = parsed['changed_files'] as List;
      expect(files.length, 1);
    });
  });
}
