// ignore_for_file: avoid_dynamic_calls
import 'dart:convert';
import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

class _MockRunner implements ProcessRunner {
  final String logOutput;

  _MockRunner(this.logOutput);

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool streamOutput = false,
  }) async {
    return ProcessResult(0, 0, logOutput, '');
  }

  @override
  Stream<String> runStream(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async* {}
}

void main() {
  group('AuditComplianceTool', () {
    test('has correct name and schema', () {
      final runner = _MockRunner('');
      final tool = AuditComplianceTool(runner);

      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema.isNotEmpty, isTrue);
      expect(tool.name, 'audit_compliance');
      expect(tool.inputSchema['required'], contains('directory'));
    });

    test('detects unsigned commits', () async {
      final log = [
        'aaa||N||alice@example.com||Alice||2024-01-01T10:00:00+00:00||feat: add login',
        'bbb||G||bob@example.com||Bob||2024-01-02T10:00:00+00:00||fix: crash',
      ].join('\n');

      final runner = _MockRunner(log);
      final tool = AuditComplianceTool(runner);

      final result = await tool.execute({'directory': '/test'});
      final parsed = jsonDecode(result) as Map<String, dynamic>;

      expect(parsed['total_commits_scanned'], 2);
      expect((parsed['unsigned_commits'] as List).length, 1);
      expect((parsed['unsigned_commits'] as List).first['hash'], 'aaa');
    });

    test('detects unrecognized emails', () async {
      final log = [
        'aaa||N||alice@example.com||Alice||2024-01-01T10:00:00+00:00||feat: add login',
        'bbb||N||unknown@hacker.com||Hacker||2024-01-02T10:00:00+00:00||fix: stuff',
      ].join('\n');

      final runner = _MockRunner(log);
      final tool = AuditComplianceTool(runner);

      final result = await tool.execute({
        'directory': '/test',
        'allowedEmails': 'alice@example.com',
      });

      final parsed = jsonDecode(result) as Map<String, dynamic>;
      final unrecognized = parsed['unrecognized_author_commits'] as List;
      expect(unrecognized.length, 1);
      expect(unrecognized.first['email'], 'unknown@hacker.com');
    });

    test('reports zero violations when all signed', () async {
      final log =
          'aaa||G||alice@example.com||Alice||2024-01-01T10:00:00+00:00||feat: ok';

      final runner = _MockRunner(log);
      final tool = AuditComplianceTool(runner);

      final result = await tool.execute({'directory': '/test'});
      final parsed = jsonDecode(result) as Map<String, dynamic>;

      expect(parsed['total_violations'], 0);
    });

    test('handles empty log', () async {
      final runner = _MockRunner('');
      final tool = AuditComplianceTool(runner);

      final result = await tool.execute({'directory': '/test'});
      final parsed = jsonDecode(result) as Map<String, dynamic>;

      expect(parsed['total_commits_scanned'], 0);
      expect(parsed['total_violations'], 0);
    });
  });
}
