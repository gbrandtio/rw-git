// ignore_for_file: avoid_dynamic_calls
import 'dart:convert';
import 'package:rw_git/rw_git.dart';
import 'package:rw_git/src/core/result.dart';
import 'package:test/test.dart';

class _MockRwGit implements RwGit {
  @override
  String get invalidGitCommandResult => 'INVALID';
  @override
  String get gitRepoIndicator => '.git';

  @override
  Future<Result<String, RwGitException>> runCommand(
    String directory,
    List<String> args, {
    bool streamOutput = false,
  }) async {
    final log = '''
commit1||feat: add UI and DB
ui/login.dart
db/schema.sql

commit2||fix: update ui
ui/login.dart
''';
    return Success(log);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  group('AnalyzeArchitectureDriftTool', () {
    test('has correct name and schema', () {
      final tool = AnalyzeArchitectureDriftTool(_MockRwGit());
      expect(tool.name, 'analyze_architecture_drift');
      expect(tool.description, isNotEmpty);
    });

    test('detects drift correctly', () async {
      final tool = AnalyzeArchitectureDriftTool(_MockRwGit());
      final result = await tool.execute({
        'directory': '/test',
        'layer_patterns': {
          'ui': '^ui/.*',
          'db': '^db/.*',
        }
      });

      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['total_commits_analyzed'], 2);
      expect(parsed['commits_with_drift'], 1);
      expect(parsed['coupling_matrix']['db']['ui'], 1);
    });
  });
}
