import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';
import 'package:rw_git/src/mcp/tools/security/detect_secrets_tool.dart';

void main() {
  group('DetectSecretsTool', () {
    test('has correct name and description', () {
      final runner = MockProcessRunner('');
      final tool = DetectSecretsTool(runner);

      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema.isNotEmpty, isTrue);
      expect(tool.name, 'detect_secrets_in_commits');
      expect(tool.description, contains('exposed secrets'));
      expect(tool.inputSchema['required'], contains('directory'));
    });

    test('throws ArgumentError if directory is missing', () async {
      final runner = MockProcessRunner('');
      final tool = DetectSecretsTool(runner);

      expect(() => tool.execute({}), throwsA(isA<ArgumentError>()));
    });

    test('returns "No exposed secrets" when none are found', () async {
      final runner = MockProcessRunner(
          'commit 12345||Author||Date||Message\n+++ b/lib/main.dart\n+  print("Hello");');
      final tool = DetectSecretsTool(runner);

      final result = await tool.execute({'directory': 'fake_dir'});
      expect(result, 'No exposed secrets or sensitive credentials found.');
    });

    test('returns formatted string with secrets when they are found', () async {
      final mockOutput = '''
e2a4b3c||John Doe||Thu Jun 26 10:00:00 2026 +0000||Add aws config
+++ b/lib/aws_config.dart
@@ -10,5 +10,6 @@
+  final awsKey = "AKIA1234567890ABCDEF";
''';
      final runner = MockProcessRunner(mockOutput);
      final tool = DetectSecretsTool(runner);

      final result =
          await tool.execute({'directory': 'fake_dir', 'limit': '1'});

      expect(result, contains('WARNING: Potential secrets exposed'));
      expect(result, contains('AKI***DEF'));
    });

    test('handles branch and limit parameters correctly', () async {
      final runner = MockProcessRunner('');
      final tool = DetectSecretsTool(runner);

      final result = await tool
          .execute({'directory': 'fake_dir', 'limit': '10', 'branch': 'main'});
      expect(result, 'No exposed secrets or sensitive credentials found.');
    });
  });
}

class MockProcessRunner implements ProcessRunner {
  final String mockOutput;

  MockProcessRunner(this.mockOutput);

  @override
  Future<ProcessResult> run(String executable, List<String> args,
      {String? workingDirectory, bool streamOutput = false}) async {
    return ProcessResult(0, 0, mockOutput, '');
  }

  @override
  Stream<String> runStream(String executable, List<String> args,
      {String? workingDirectory}) async* {
    final lines = mockOutput.split('\n');
    for (final line in lines) {
      yield line;
    }
  }
}
