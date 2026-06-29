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

    test('findSuspiciousCommits handles malformed commit headers', () async {
      String mockGitLog = [
        'a1b2c3d4e5f6||FIXME: this is a hack', // 2 parts, flagged in header
        'b2c3d4e5f6g7||Author B', // 2 parts, no keyword
        '+ FIXME: in diff', // Flagged in diff, using 2 parts header
      ].join('\n');
      final runner = MockProcessRunner(mockGitLog);
      final tracker = CodeQualityTracker(runner);

      final suspicious = await tracker.findSuspiciousCommits('dummyDir');

      expect(suspicious.length, 2);
      expect(suspicious, contains('a1b2c3d4e5f6 - FIXME: this is a hack'));
      expect(suspicious, contains('b2c3d4e5f6g7 - Author B'));
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
      expect(result.length, 1);
      final item = result.first;
      expect(item['commit'], contains('e2a4b3c - John Doe'));
      expect(item['file'], 'lib/feature.dart');
      expect(item['diff_block'], contains('+  // TODO: Refactor this later'));
      expect(item['diff_block'],
          contains('+    /// This is an LLM generated doc comment'));
      expect(item['diff_block'], contains('class Feature {'));
    });

    test('extractChangedComments passes limit parameter correctly', () async {
      final runner = MockProcessRunner('');
      final tracker = CodeQualityTracker(runner);
      await tracker.extractChangedComments('fake_dir', limit: '10');
    });

    test('findSecrets detects various types of exposed secrets', () async {
      final mockOutput = '''
e2a4b3c||John Doe||Thu Jun 26 10:00:00 2026 +0000||Add complex feature
+++ b/lib/aws_config.dart
@@ -10,5 +10,6 @@
+  final awsKey = "AKIA1234567890ABCDEF";
+++ b/lib/stripe.dart
@@ -10,5 +10,6 @@
+  String stripeLiveKey = "sk_live_1234567890abcdef12345678";
+++ b/lib/slack.dart
@@ -10,5 +10,6 @@
+  var token = "xoxb-123456789012-1234567890123-abcdef1234567890abcdef12";
+++ b/lib/jwt.dart
@@ -10,5 +10,6 @@
+  // My token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
+++ b/lib/safe.dart
@@ -1,2 +1,3 @@
+  final url = "https://example.com";
''';
      final runner = MockProcessRunner(mockOutput);
      final tracker = CodeQualityTracker(runner);

      final secrets = await tracker.findSecrets('fake_dir');

      expect(secrets.length, 4);
      expect(secrets[0], contains('AKI***DEF')); // AWS redacted
      expect(secrets[1], contains('sk_***678')); // Stripe redacted
      expect(secrets[2], contains('xox***012')); // Slack
      // check if JWT is caught
      expect(secrets[3], contains('tok***w5c'));
    });

    test('findSecrets passes limit and branch parameters correctly', () async {
      final runner = MockProcessRunner('');
      final tracker = CodeQualityTracker(runner);
      await tracker.findSecrets('fake_dir', limit: '10', branch: 'main');
    });

    test(
        'findSecrets avoids false positives in lockfiles, tests, and CI variables',
        () async {
      final mockOutput = '''
e2a4b3c||John Doe||Thu Jun 26 10:00:00 2026 +0000||Update dependencies
+++ b/package-lock.json
@@ -10,5 +10,6 @@
+  "integrity": "sha512-ABCDEF1234567890abcdefABCDEF1234567890abcdefABCDEF1234567890abcdefABCDEF1234567890abcd=="
+++ b/lib/tests/api_test.dart
@@ -10,5 +10,6 @@
+  final token = "api***key";
+++ b/.github/workflows/ci.yml
@@ -10,5 +10,6 @@
+  token: \${{ secrets.GITHUB_TOKEN }}
+++ b/lib/config.dart
@@ -10,5 +10,6 @@
+  final placeholder = "YOUR_API_KEY_HERE_123456";
''';
      final runner = MockProcessRunner(mockOutput);
      final tracker = CodeQualityTracker(runner);

      final secrets = await tracker.findSecrets('fake_dir');

      expect(secrets, isEmpty);
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
