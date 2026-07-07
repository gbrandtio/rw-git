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
  group('SecretsScanner', () {
    test('forwards since/until as git flags', () async {
      final runner = MockProcessRunner();
      await SecretsScanner(runner)
          .findSecrets('./test', since: '2024-01-01', until: '2024-12-31');
      expect(runner.lastArgs, contains('--since=2024-01-01'));
      expect(runner.lastArgs, contains('--until=2024-12-31'));
    });

    test('omits since/until flags when not provided', () async {
      final runner = MockProcessRunner();
      await SecretsScanner(runner).findSecrets('./test');
      expect(runner.lastArgs!.any((a) => a.startsWith('--since=')), isFalse);
      expect(runner.lastArgs!.any((a) => a.startsWith('--until=')), isFalse);
    });

    test(
        'places --since=/--until= before the trailing positional branch '
        'argument, so git does not misparse the revision range', () async {
      final runner = MockProcessRunner();
      await SecretsScanner(runner).findSecrets('./test',
          since: '2024-01-01', until: '2024-12-31', branch: 'feature/x');

      final args = runner.lastArgs!;
      final sinceIndex = args.indexOf('--since=2024-01-01');
      final untilIndex = args.indexOf('--until=2024-12-31');
      final branchIndex = args.indexOf('feature/x');

      expect(sinceIndex, greaterThanOrEqualTo(0));
      expect(untilIndex, greaterThanOrEqualTo(0));
      expect(branchIndex, equals(args.length - 1));
      expect(sinceIndex, lessThan(branchIndex));
      expect(untilIndex, lessThan(branchIndex));
    });
  });
}
