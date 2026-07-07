import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

class MockProcessRunner implements ProcessRunner {
  List<String>? lastArgs;

  @override
  Future<ProcessResult> run(String ex, List<String> arg,
      {String? workingDirectory, bool streamOutput = false}) async {
    lastArgs = arg;
    return ProcessResult(0, 0, '', '');
  }

  @override
  Stream<String> runStream(String ex, List<String> arg,
          {String? workingDirectory}) =>
      throw UnimplementedError();
}

void main() {
  group('ComplianceScanner', () {
    test('forwards since/until as git flags', () async {
      final runner = MockProcessRunner();
      await ComplianceScanner(runner).scanComplianceIssues('./test',
          since: '2024-01-01', until: '2024-12-31');
      expect(runner.lastArgs, contains('--since=2024-01-01'));
      expect(runner.lastArgs, contains('--until=2024-12-31'));
    });

    test('omits since/until flags when not provided', () async {
      final runner = MockProcessRunner();
      await ComplianceScanner(runner).scanComplianceIssues('./test');
      expect(runner.lastArgs!.any((a) => a.startsWith('--since=')), isFalse);
      expect(runner.lastArgs!.any((a) => a.startsWith('--until=')), isFalse);
    });
  });
}
