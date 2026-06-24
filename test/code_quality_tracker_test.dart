import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

void main() {
  group('CodeQualityTracker', () {
    test(
        'calculateChurn will correctly parse the unified diff output from git log',
        () async {
      String mockGitLogP = '''
commit a1b2c3d4e5f6
Author: John Doe <john@doe.com>
Date:   Wed Jun 24 14:00:00 2026 +0000

    Some commit message

diff --git a/lib/main.dart b/lib/main.dart
index 123456..789012 100644
--- a/lib/main.dart
+++ b/lib/main.dart
@@ -10,5 +10,6 @@ class RwGitFacade {
   }
 }
@@ -20,2 +21,3 @@ void main() {
   print('Hello');
 }

diff --git a/lib/main.dart b/lib/main.dart
index 123456..789012 100644
--- a/lib/main.dart
+++ b/lib/main.dart
@@ -10,5 +10,6 @@ class RwGitFacade {
   }
 }
''';

      // We use MockProcessRunner from the other test file if it exists, or just a dummy one.
      // But actually, we don't need a mock if we just test the isolate method directly.
      // Since it's private, we can't test it directly unless we use MockProcessRunner.
      // Since `MockProcessRunner` isn't accessible, let's create a quick local mock.
      final runner = MockProcessRunner(mockGitLogP);
      final tracker = CodeQualityTracker(runner);

      final ChurnMetricsDto result = await tracker.calculateChurn('dummyDir');

      expect(result.totalCommits, 10);
      expect(result.fileChurn['lib/main.dart'], 2);
      expect(result.blockChurn['class RwGitFacade {'], 2);
      expect(result.blockChurn['void main() {'], 1);

      expect(result.classChurn['RwGitFacade'], 2);
    });
  });
}

class MockProcessRunner implements ProcessRunner {
  final String mockOutput;
  MockProcessRunner(this.mockOutput);

  @override
  Future<ProcessResult> run(String executable, List<String> args,
      {String? workingDirectory, bool runInShell = false}) async {
    if (args.contains('rev-list') && args.contains('--count')) {
      return ProcessResult(0, 0, '10\n', ''); // Mock 10 commits
    }
    return ProcessResult(0, 0, mockOutput, '');
  }
}
