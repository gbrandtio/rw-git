// ignore_for_file: avoid_dynamic_calls
import 'dart:convert';
import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

class _MockRunner implements ProcessRunner {
  final String mergeBase;
  final String diffA;
  final String diffB;

  _MockRunner({
    this.mergeBase = 'abc123',
    this.diffA = '',
    this.diffB = '',
  });

  int _callIndex = 0;

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool streamOutput = false,
  }) async {
    _callIndex++;
    if (arguments.contains('merge-base')) {
      return ProcessResult(0, 0, mergeBase, '');
    }
    if (arguments.contains('--name-only')) {
      // First diff call = branchA, second = branchB
      if (_callIndex <= 2) {
        return ProcessResult(0, 0, diffA, '');
      }
      return ProcessResult(0, 0, diffB, '');
    }
    return ProcessResult(0, 0, '', '');
  }

  @override
  Stream<String> runStream(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async* {}
}

void main() {
  group('PredictMergeConflictsTool', () {
    test('has correct name and schema', () {
      final runner = _MockRunner();
      final tool = PredictMergeConflictsTool(runner);

      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema.isNotEmpty, isTrue);
      expect(tool.name, 'predict_merge_conflicts');
      expect(
        tool.inputSchema['required'],
        containsAll(['directory', 'branchA', 'branchB']),
      );
    });

    test('detects conflicting files on both branches', () async {
      final runner = _MockRunner(
        mergeBase: 'abc123\n',
        diffA: 'shared.dart\nonly_a.dart\n',
        diffB: 'shared.dart\nonly_b.dart\n',
      );
      final tool = PredictMergeConflictsTool(runner);

      final result = await tool.execute({
        'directory': '/test',
        'branchA': 'feature-a',
        'branchB': 'feature-b',
      });

      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['merge_base'], 'abc123');
      expect(parsed['logical_conflicting_files'], contains('shared.dart'));
      expect(parsed['files_only_on_a'], contains('only_a.dart'));
      expect(parsed['files_only_on_b'], contains('only_b.dart'));
    });

    test('returns none risk when no conflicts', () async {
      final runner = _MockRunner(
        mergeBase: 'abc123\n',
        diffA: 'only_a.dart\n',
        diffB: 'only_b.dart\n',
      );
      final tool = PredictMergeConflictsTool(runner);

      final result = await tool.execute({
        'directory': '/test',
        'branchA': 'feature-a',
        'branchB': 'feature-b',
      });

      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['risk_level'], 'none');
      expect(parsed['logical_conflicting_files_count'], 0);
    });

    test('returns medium risk when 5 conflicts', () async {
      final runner = _MockRunner(
        mergeBase: 'abc123\n',
        diffA: 'c1.dart\nc2.dart\nc3.dart\nc4.dart\nc5.dart\n',
        diffB: 'c1.dart\nc2.dart\nc3.dart\nc4.dart\nc5.dart\n',
      );
      final tool = PredictMergeConflictsTool(runner);
      final result = await tool.execute({
        'directory': '/test',
        'branchA': 'feature-a',
        'branchB': 'feature-b',
      });
      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['risk_level'], 'medium');
    });
  });
}
