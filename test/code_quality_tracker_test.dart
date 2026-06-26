// ignore_for_file: avoid_dynamic_calls, unnecessary_cast
import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

void main() {
  group('CodeQualityTracker', () {
    test('calculateChurn parses unified diff output correctly', () async {
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

      final runner = MockProcessRunner(mockGitLogP);
      final tracker = CodeQualityTracker(runner);

      final ChurnMetricsDto result = await tracker.calculateChurn('dummyDir');

      expect(result.totalCommits, 10);
      expect(result.fileChurn['lib/main.dart'], 2);
      expect(result.blockChurn['class RwGitFacade {'], 2);
      expect(result.blockChurn['void main() {'], 1);
      expect(result.classChurn['RwGitFacade'], 2);
    });

    test('calculateChurn passes limit parameter correctly', () async {
      final runner = MockProcessRunner('');
      final tracker = CodeQualityTracker(runner);
      await tracker.calculateChurn('dummyDir', limit: '10');
      // No exception means it passed
    });

    test(
        'calculateChurnWithAuthors parses unified diff output with authors correctly',
        () async {
      String mockGitLogP = '''
commit a1b2c3d4e5f6
AUTHOR: Alice
Date:   Wed Jun 24 14:00:00 2026 +0000

    Some commit message

diff --git a/lib/main.dart b/lib/main.dart
index 123456..789012 100644
--- a/lib/main.dart
+++ b/lib/main.dart
@@ -10,5 +10,6 @@ class RwGitFacade {
   }
 }

commit b2c3d4e5f6g7
AUTHOR: Bob

diff --git a/lib/main.dart b/lib/main.dart
index 123456..789012 100644
--- a/lib/main.dart
+++ b/lib/main.dart
@@ -10,5 +10,6 @@ class RwGitFacade {
''';

      final runner = MockProcessRunner(mockGitLogP);
      final tracker = CodeQualityTracker(runner);

      final result = await tracker.calculateChurnWithAuthors('dummyDir');

      expect(result.totalCommits, 10);
      expect(result.fileChurn['lib/main.dart']?.total, 2);
      expect(result.fileChurn['lib/main.dart']?.authors['Alice'], 1);
      expect(result.fileChurn['lib/main.dart']?.authors['Bob'], 1);

      expect(result.blockChurn['class RwGitFacade {']?.total, 2);
      expect(result.classChurn['RwGitFacade']?.total, 2);
    });

    test('calculateChurnWithAuthors passes limit parameter correctly',
        () async {
      final runner = MockProcessRunner('');
      final tracker = CodeQualityTracker(runner);
      await tracker.calculateChurnWithAuthors('dummyDir', limit: '10');
    });

    test('findSuspiciousCommits identifies commits with suspicious keywords',
        () async {
      String mockGitLog = [
        'a1b2c3d4e5f6||Author A||Date A||Implemented feature X',
        'b2c3d4e5f6g7||Author B||Date B||FIXME: this is a hack',
        'c3d4e5f6g7h8||Author C||Date C||Added a new temporary file',
        'd4e5f6g7h8i9||Author D||Date D||Cleaned up code',
        'e5f6g7h8i9j0||Author E||Date E||todo: refactor this',
        'f6g7h8i9j0k1||Author F||Date F||Normal commit with those letters in the middle of a word like atodont',
      ].join('\n');
      final runner = MockProcessRunner(mockGitLog);
      final tracker = CodeQualityTracker(runner);

      final suspicious = await tracker.findSuspiciousCommits('dummyDir');

      expect(suspicious.length, 3);
      expect(suspicious,
          contains('b2c3d4e5f6g7 - Author B (Date B): FIXME: this is a hack'));
      expect(
          suspicious,
          contains(
              'c3d4e5f6g7h8 - Author C (Date C): Added a new temporary file'));
      expect(suspicious,
          contains('e5f6g7h8i9j0 - Author E (Date E): todo: refactor this'));
    });

    test('findSuspiciousCommits passes limit parameter correctly', () async {
      final runner = MockProcessRunner('');
      final tracker = CodeQualityTracker(runner);
      await tracker.findSuspiciousCommits('dummyDir', limit: '10');
    });

    test('findMegaCommits identifies commits exceeding thresholds', () async {
      String mockGitLog = '''
a1b2c3d4e5f6||Author A||Date A||Small commit
 1 file changed, 10 insertions(+), 5 deletions(-)

b2c3d4e5f6g7||Author B||Date B||Many files
 25 files changed, 10 insertions(+), 5 deletions(-)

c3d4e5f6g7h8||Author C||Date C||Many lines
 2 files changed, 400 insertions(+), 150 deletions(-)

d4e5f6g7h8i9||Author D||Date D||Normal
 5 files changed, 100 insertions(+), 10 deletions(-)

e5f6g7h8i9j0||Author E||Date E||Many insertions
 600 insertions(+)

f6g7h8i9j0k1||Author F||Date F||Many deletions
 600 deletions(-)
''';
      final runner = MockProcessRunner(mockGitLog);
      final tracker = CodeQualityTracker(runner);

      final mega = await tracker.findMegaCommits('dummyDir');

      expect(mega.length, 4);
      expect(
          mega,
          contains(
              'b2c3d4e5f6g7 - Author B (Date B): Many files')); // Exceeds 20 files
      expect(
          mega,
          contains(
              'c3d4e5f6g7h8 - Author C (Date C): Many lines')); // Exceeds 500 lines (400 + 150)
      expect(
          mega,
          contains(
              'e5f6g7h8i9j0 - Author E (Date E): Many insertions')); // Exceeds 500 insertions
      expect(
          mega,
          contains(
              'f6g7h8i9j0k1 - Author F (Date F): Many deletions')); // Exceeds 500 deletions
    });

    test('findMegaCommits passes limit parameter correctly', () async {
      final runner = MockProcessRunner('');
      final tracker = CodeQualityTracker(runner);
      await tracker.findMegaCommits('dummyDir', limit: '10');
    });

    test('findMegaCommits handles empty output', () async {
      final runner = MockProcessRunner('');
      final tracker = CodeQualityTracker(runner);
      final mega = await tracker.findMegaCommits('dummyDir');
      expect(mega, isEmpty);
    });

    test('findSuspiciousCommits throws RwGitException when process fails',
        () async {
      final runner = MockProcessRunner('', exitCode: 128);
      final tracker = CodeQualityTracker(runner);

      expect(() => tracker.findSuspiciousCommits('dummyDir'),
          throwsA(isA<RwGitException>()));
    });

    test('calculateChurn handles empty output gracefully', () async {
      final runner = MockProcessRunner('');
      final tracker = CodeQualityTracker(runner);

      final result = await tracker.calculateChurn('dummyDir');
      expect(result.fileChurn, isEmpty);
      expect(result.classChurn, isEmpty);
      expect(result.blockChurn, isEmpty);
    });

    test(
        'findSuspiciousCommits identifies commits with suspicious keywords in diffs',
        () async {
      String mockGitLogP = '''
a1b2c3d4e5f6||Author A||Date A||Normal message
diff --git a/file.dart b/file.dart
--- a/file.dart
+++ b/file.dart
@@ -10,2 +10,3 @@
+ // FIXME: this is a hack
+ print('test');
b2c3d4e5f6g7||Author B||Date B||Another message
diff --git a/file2.dart b/file2.dart
--- a/file2.dart
+++ b/file2.dart
@@ -10,2 +10,3 @@
- // fixme
+ // good code
''';
      final runner = MockProcessRunner(mockGitLogP);
      final tracker = CodeQualityTracker(runner);

      final suspicious = await tracker.findSuspiciousCommits('dummyDir');

      expect(suspicious.length, 1);
      expect(suspicious,
          contains('a1b2c3d4e5f6 - Author A (Date A): Normal message'));
    });

    test('extractChangedComments extracts comments with context correctly',
        () async {
      final mockOutput = '''
e2a4b3c||John Doe||Thu Jun 26 10:00:00 2026 +0000||Add complex feature
+++ b/lib/feature.dart
@@ -10,5 +10,6 @@
 class Feature {
+  // TODO: Refactor this later
   void execute() {
+    /// This is an LLM generated doc comment
+    final x = 42;
   }
 }
''';
      final runner = MockProcessRunner(mockOutput);
      final tracker = CodeQualityTracker(runner);

      final result = await tracker.extractChangedComments('fake_dir');
      expect(result, contains('Commit: e2a4b3c - John Doe'));
      expect(result, contains('File: lib/feature.dart'));
      expect(result, contains('+  // TODO: Refactor this later'));
      expect(result, contains('+    /// This is an LLM generated doc comment'));
      expect(result, contains('class Feature {'));
    });

    test('extractChangedComments passes limit parameter correctly', () async {
      final runner = MockProcessRunner('');
      final tracker = CodeQualityTracker(runner);
      await tracker.extractChangedComments('fake_dir', limit: '10');
    });
  });
}

class MockProcessRunner implements ProcessRunner {
  final String mockOutput;
  final int exitCode;

  MockProcessRunner(this.mockOutput, {this.exitCode = 0});

  @override
  Future<ProcessResult> run(String executable, List<String> args,
      {String? workingDirectory, bool streamOutput = false}) async {
    if (args.contains('rev-list') && args.contains('--count')) {
      return ProcessResult(0, exitCode, '10\n', ''); // Mock 10 commits
    }
    return ProcessResult(0, exitCode, mockOutput, 'mock stderr');
  }

  @override
  Stream<String> runStream(String executable, List<String> args,
      {String? workingDirectory}) async* {
    if (exitCode != 0) {
      throw RwGitException(
          message: 'Git command failed',
          exitCode: exitCode,
          stderr: 'mock stderr');
    }
    final lines = mockOutput.split('\n');
    for (final line in lines) {
      yield line;
    }
  }
}
