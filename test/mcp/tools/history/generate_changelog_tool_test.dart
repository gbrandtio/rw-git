// ignore_for_file: avoid_dynamic_calls
import 'dart:convert';
import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:rw_git/src/core/result.dart';
import 'package:rw_git/src/vcs/git_query.dart';
import 'package:test/test.dart';

/// Resolves nothing: every SZZ trace comes back empty, isolating the
/// Conventional Commits grouping behaviour under test.
class _SilentMockProcessRunner implements ProcessRunner {
  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool streamOutput = false,
  }) async =>
      ProcessResult(0, 0, '', '');

  @override
  Stream<String> runStream(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) =>
      throw UnimplementedError();
}

/// Scripted runner for the shared RA-SZZ pipeline: exact-argument mocks so
/// the test fails if the changelog tool stops issuing the same git commands
/// as the other SZZ-backed tools.
class _ScriptedMockProcessRunner implements ProcessRunner {
  final Map<String, String> _mocks = {};

  void mockResult(String executable, List<String> arguments, String stdout) {
    _mocks['$executable ${arguments.join(' ')}'] = stdout;
  }

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool streamOutput = false,
  }) async {
    final cmd = '$executable ${arguments.join(' ')}';
    return ProcessResult(0, 0, _mocks[cmd] ?? '', '');
  }

  @override
  Stream<String> runStream(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) =>
      throw UnimplementedError();
}

class _MockGitQuery implements GitQuery {
  final String logOutput;

  _MockGitQuery(this.logOutput);

  @override
  Future<Result<String, RwGitException>> run(
    String directory,
    List<String> args,
  ) async {
    if (args.contains('show')) {
      return const Success('file1.dart\nfile2.dart');
    }
    if (args.contains('rev-parse')) {
      return const Success('parent_hash');
    }
    if (args.contains('diff')) {
      return const Success('--- a/file1.dart\n@@ -10,2 +10,2 @@\n- old\n+ new');
    }
    if (args.contains('blame')) {
      return const Success(
        '00000000 (Alice 2024-01-01) old\n12345678 (Bob 2024-01-02) new',
      );
    }
    return Success(logOutput);
  }
}

void main() {
  group('GenerateChangelogTool', () {
    test('has correct name and schema', () {
      final tool = GenerateChangelogTool(
        _MockGitQuery(''),
        SzzAlgorithm(_SilentMockProcessRunner()),
      );

      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema.isNotEmpty, isTrue);
      expect(tool.name, 'generate_changelog');
      expect(
        tool.inputSchema['required'],
        containsAll(['directory', 'from', 'to']),
      );
    });

    test('groups conventional commits correctly', () async {
      final log = [
        'aaa||Alice||feat: add login page',
        'bbb||Bob||fix: resolve crash on startup',
        'ccc||Alice||chore: update dependencies',
        'ddd||Carol||feat(auth)!: BREAKING CHANGE redesign API',
      ].join('\n');

      final tool = GenerateChangelogTool(
        _MockGitQuery(log),
        SzzAlgorithm(_SilentMockProcessRunner()),
      );

      final result = await tool.execute({
        'directory': '/test',
        'from': 'v1.0.0',
        'to': 'v2.0.0',
      });

      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['total_commits'], 4);
      expect((parsed['features'] as List).length, 1);
      expect((parsed['fixes'] as List).length, 1);
      expect((parsed['breaking_changes'] as List).length, 1);
      expect((parsed['other'] as List).length, 1);
      expect(parsed['contributors'], containsAll(['Alice', 'Bob', 'Carol']));
    });

    test('handles non-conventional commits', () async {
      final log = [
        'aaa||Alice||Updated the readme',
        'bbb||Bob||Fixed a bug',
      ].join('\n');

      final tool = GenerateChangelogTool(
        _MockGitQuery(log),
        SzzAlgorithm(_SilentMockProcessRunner()),
      );

      final result = await tool.execute({
        'directory': '/test',
        'from': 'v1.0.0',
        'to': 'v2.0.0',
      });

      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['total_commits'], 2);
      expect((parsed['other'] as List).length, 2);
      expect((parsed['features'] as List).length, 0);
    });

    test('handles empty log', () async {
      final tool = GenerateChangelogTool(
        _MockGitQuery(''),
        SzzAlgorithm(_SilentMockProcessRunner()),
      );

      final result = await tool.execute({
        'directory': '/test',
        'from': 'v1.0.0',
        'to': 'v2.0.0',
      });

      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['total_commits'], 0);
    });

    test('handles exceptions gracefully', () async {
      final mock = _MockGitQuery('');
      final tool = GenerateChangelogTool(
        mock,
        SzzAlgorithm(_SilentMockProcessRunner()),
      );
      // Simulate an error by catching the thrown exception from getStringArgument
      try {
        await tool.execute({'directory': null, 'from': 'v1', 'to': 'v2'});
        fail('Should throw exception');
      } catch (e) {
        expect(e, isA<ArgumentError>());
      }
    });

    test(
        'fix enrichment runs through the shared RA-SZZ core: introducing '
        'commits carry temporal context and refactoring commits are excluded',
        () async {
      const fixHash = 'bbb';
      const parentHash = '1111222233334444555566667777888899990000';
      const bugOriginHash = 'aaaa5678aaaa5678aaaa5678aaaa5678aaaa5678';
      const refactorOriginHash = 'cccc5678cccc5678cccc5678cccc5678cccc5678';

      final runner = _ScriptedMockProcessRunner();
      runner.mockResult(
        'git',
        ['log', '-1', '--format=format:%H%x09%an%x09%ae%x09%aI%x09%s', fixHash],
        '$fixHash\tBob\tbob@x.com\t2024-02-01T00:00:00Z\tfix: resolve crash on startup\n',
      );
      runner.mockResult('git', ['rev-parse', '$fixHash^'], '$parentHash\n');
      runner.mockResult(
        'git',
        ['diff', '-M', '-w', '--ignore-blank-lines', parentHash, fixHash],
        '--- a/lib/a.dart\n'
            '+++ b/lib/a.dart\n'
            '@@ -5 +5,0 @@\n'
            '-  crashOnStartup(config);\n'
            '@@ -9 +8,0 @@\n'
            '-  helperMovedEarlier(config);\n',
      );
      runner.mockResult(
        'git',
        [
          'blame', '--date=iso-strict', '-l', '-w', '-C', '-C', '-M', //
          '-L', '5,5', parentHash, '--', 'lib/a.dart',
        ],
        '$bugOriginHash (Alice 2024-01-01T00:00:00+00:00 5) crashOnStartup(config);\n',
      );
      runner.mockResult(
        'git',
        [
          'blame', '--date=iso-strict', '-l', '-w', '-C', '-C', '-M', //
          '-L', '9,9', parentHash, '--', 'lib/a.dart',
        ],
        '$refactorOriginHash (Carol 2024-01-10T00:00:00+00:00 9) helperMovedEarlier(config);\n',
      );
      runner.mockResult(
        'git',
        [
          'log',
          '-1',
          '--format=format:%H%x09%an%x09%ae%x09%aI%x09%s',
          bugOriginHash,
        ],
        '$bugOriginHash\tAlice\talice@x.com\t2024-01-01T00:00:00Z\tfeat: add startup config\n',
      );
      runner.mockResult(
        'git',
        [
          'log',
          '-1',
          '--format=format:%H%x09%an%x09%ae%x09%aI%x09%s',
          refactorOriginHash,
        ],
        '$refactorOriginHash\tCarol\tcarol@x.com\t2024-01-10T00:00:00Z\trefactor: extract startup helpers\n',
      );

      final tool = GenerateChangelogTool(
        _MockGitQuery('bbb||Bob||fix: resolve crash on startup'),
        SzzAlgorithm(runner),
      );

      final result = await tool.execute({
        'directory': '/test',
        'from': 'v1.0.0',
        'to': 'v2.0.0',
      });

      final parsed = jsonDecode(result) as Map<String, dynamic>;
      final fixes = parsed['fixes'] as List;
      expect(fixes, hasLength(1));

      final introducing = fixes.first['bug_introducing_commits'] as List;
      // The refactoring-introduced attribution must be discarded (RA-SZZ);
      // only the genuine origin survives, with the temporal context the
      // changelog contract documents.
      expect(introducing, hasLength(1));
      expect(introducing.first['introducing_commit'], bugOriginHash);
      expect(introducing.first['introduced_date'], '2024-01-01T00:00:00.000Z');
      expect(introducing.first['days_bug_lived'], 31.0);
    });

    test('includes raw log when includeRawMessages is true', () async {
      final log = 'aaa||Alice||Updated the readme';
      final tool = GenerateChangelogTool(
        _MockGitQuery(log),
        SzzAlgorithm(_SilentMockProcessRunner()),
      );

      final result = await tool.execute({
        'directory': '/test',
        'from': 'v1.0.0',
        'to': 'v2.0.0',
        'includeRawMessages': true,
      });

      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['total_commits'], 1);
      expect(parsed['raw_log'], log);
    });
  });
}
