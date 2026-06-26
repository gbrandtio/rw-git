// ignore_for_file: avoid_dynamic_calls, unnecessary_cast
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

void main() {
  group('Exceptions', () {
    test('RwGitException toString contains all fields', () {
      final e = RwGitException(
        message: 'Test message',
        exitCode: 1,
        stderr: 'Test stderr',
        originalException: 'Original error',
      );
      final s = e.toString();
      expect(s, contains('Test message'));
      expect(s, contains('Exit code: 1'));
      expect(s, contains('Stderr: Test stderr'));
      expect(s, contains('Original exception: Original error'));
    });

    test('GitBranchNotFoundException has correct message', () {
      final e = GitBranchNotFoundException('feature-branch');
      expect(e.message, 'Branch not found: feature-branch');
    });

    test('GitNotInitializedException has correct message', () {
      final e = GitNotInitializedException('/fake/dir');
      expect(e.message, 'Directory is not a git repository: /fake/dir');
    });

    test('GitExecutableNotFoundException has default and custom message', () {
      final e1 = GitExecutableNotFoundException();
      expect(e1.message, contains('Failed to execute git'));

      final e2 =
          GitExecutableNotFoundException(message: 'Custom git path missing');
      expect(e2.message, 'Custom git path missing');
    });

    test('GitMergeConflictException has correct message', () {
      final e = GitMergeConflictException();
      expect(e.message, 'Merge conflict detected.');
    });
  });
}
