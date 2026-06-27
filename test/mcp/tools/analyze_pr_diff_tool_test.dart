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
      if (key.contains(entry.key)) {
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

  _MockRwGit({
    this.numstatOutput = '',
    this.logOutput = '',
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
    if (args.contains('--numstat')) {
      return Success(numstatOutput);
    }
    if (args.contains('-p')) {
      return Success(logOutput);
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
      final tracker = CodeQualityTracker(runner);
      final rwGit = _MockRwGit();
      final tool = AnalyzePrDiffTool(tracker, rwGit);

      expect(tool.name, 'analyze_pr_diff');
      expect(tool.inputSchema['required'],
          containsAll(['directory', 'base', 'head']));
    });

    test('returns structured JSON with risk scores', () async {
      final runner = _MockRunner();
      runner.setResult('git', ['rev-list', '--count'], '100');

      final numstat = '50\t10\tlib/src/main.dart\n5\t2\tREADME.md';
      final logOutput = '';

      final tracker = CodeQualityTracker(runner);
      final rwGit = _MockRwGit(
        numstatOutput: numstat,
        logOutput: logOutput,
      );
      final tool = AnalyzePrDiffTool(tracker, rwGit);

      final result = await tool.execute({
        'directory': '/test',
        'base': 'main',
        'head': 'feature',
      });

      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed.containsKey('total_files_changed'), isTrue);
      expect(parsed.containsKey('overall_risk_level'), isTrue);
      expect(parsed.containsKey('changed_files'), isTrue);
    });

    test('respects topN parameter', () async {
      final runner = _MockRunner();
      runner.setResult('git', ['rev-list', '--count'], '100');

      final numstat =
          '10\t5\tfile1.dart\n20\t10\tfile2.dart\n30\t15\tfile3.dart';

      final tracker = CodeQualityTracker(runner);
      final rwGit = _MockRwGit(numstatOutput: numstat);
      final tool = AnalyzePrDiffTool(tracker, rwGit);

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
