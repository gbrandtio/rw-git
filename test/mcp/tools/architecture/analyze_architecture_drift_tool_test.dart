import 'dart:convert';
import 'package:test/test.dart';
import 'package:rw_git/rw_git.dart';
import 'package:rw_git/src/core/result.dart';

class _MockRwGit implements RwGit {
  final String logOutput;
  final bool shouldFail;

  _MockRwGit({this.logOutput = '', this.shouldFail = false});

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
    if (shouldFail) {
      return Failure(RwGitException(message: 'Failed'));
    }
    return Success(logOutput);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test('AnalyzeArchitectureDriftTool properties', () async {
    final tool = AnalyzeArchitectureDriftTool(RwGit());
    expect(tool.name, 'analyze_architecture_drift');
    expect(tool.description, isNotEmpty);
    expect(tool.inputSchema, isNotEmpty);

    final res = await tool
        .execute({'directory': '.', 'layer_patterns': <String, dynamic>{}});
    expect(res, isNotNull);
  });

  test('AnalyzeArchitectureDriftTool handles failures', () async {
    final tool = AnalyzeArchitectureDriftTool(_MockRwGit(shouldFail: true));
    final res = await tool.execute({
      'directory': '.',
      'layer_patterns': {'ui': 'lib/ui'}
    });
    expect(res, contains('error'));
  });

  test('AnalyzeArchitectureDriftTool rejects malformed regex pattern',
      () async {
    final tool = AnalyzeArchitectureDriftTool(_MockRwGit());
    final res = await tool.execute({
      'directory': '.',
      'layer_patterns': {'ui': '(unclosed'},
    });
    final data = jsonDecode(res) as Map<String, dynamic>;
    expect(data['error'], contains('Invalid regex pattern'));
    expect(data['error'], contains('ui'));
  });

  test('AnalyzeArchitectureDriftTool detects coupling matrix', () async {
    final logOut = '''
hash1||commit 1
lib/ui/widget.dart
lib/data/repo.dart

hash2||commit 2
lib/ui/another.dart
''';
    final tool = AnalyzeArchitectureDriftTool(_MockRwGit(logOutput: logOut));
    final res = await tool.execute({
      'directory': '.',
      'layer_patterns': {
        'ui': 'lib/ui/',
        'data': 'lib/data/',
      }
    });

    final data = jsonDecode(res) as Map<String, dynamic>;
    expect(data['total_commits_analyzed'], 2);
    expect(data['commits_with_drift'], 1);
    final matrix = data['coupling_matrix'] as Map<String, dynamic>;
    final uiMatrix = matrix['ui'] as Map<String, dynamic>;
    final dataMatrix = matrix['data'] as Map<String, dynamic>;
    expect(uiMatrix['data'], 1);
    expect(dataMatrix['ui'], 1);
    final driftCommits = data['drift_commits'] as List<dynamic>;
    final firstCommit = driftCommits.first as Map<String, dynamic>;
    expect(firstCommit['hash'], 'hash1');
  });

  test(
      'AnalyzeArchitectureDriftTool returns coupling_ratio and coupling_density',
      () async {
    final logOut = '''
hash1||commit 1
lib/ui/widget.dart
lib/data/repo.dart

hash2||commit 2
lib/ui/another.dart
''';
    final tool = AnalyzeArchitectureDriftTool(_MockRwGit(logOutput: logOut));
    final res = await tool.execute({
      'directory': '.',
      'layer_patterns': {
        'ui': 'lib/ui/',
        'data': 'lib/data/',
      }
    });

    final data = jsonDecode(res) as Map<String, dynamic>;
    expect(data.containsKey('coupling_ratio'), isTrue);
    expect(data.containsKey('coupling_density'), isTrue);
    expect(data['coupling_ratio'], isA<double>());
    expect(data['coupling_density'], isA<double>());
    // 1 drift commit out of 2 total → ratio = 0.5
    expect(data['coupling_ratio'], closeTo(0.5, 0.001));
    // 2 layers, 1 possible pair, 1 coupled → density = 1.0
    expect(data['coupling_density'], closeTo(1.0, 0.001));
  });

  test('AnalyzeArchitectureDriftTool detects God Component smell', () async {
    // All 3 drift commits involve the 'core' layer → God Component
    final logOut = '''
h1||feat
lib/core/a.dart
lib/ui/b.dart

h2||feat
lib/core/c.dart
lib/data/d.dart

h3||feat
lib/core/e.dart
lib/ui/f.dart

h4||chore
lib/docs/readme.md
''';
    final tool = AnalyzeArchitectureDriftTool(_MockRwGit(logOutput: logOut));
    final res = await tool.execute({
      'directory': '.',
      'layer_patterns': {
        'core': 'lib/core/',
        'ui': 'lib/ui/',
        'data': 'lib/data/',
      }
    });

    final data = jsonDecode(res) as Map<String, dynamic>;
    final smells = data['architectural_smells'] as List<dynamic>;
    expect(smells.any((s) => (s as Map)['type'] == 'God Component'), isTrue);
  });

  test('AnalyzeArchitectureDriftTool detects Scattered Functionality smell',
      () async {
    // One commit touches 3 layers → Scattered Functionality
    final logOut = '''
h1||feat
lib/ui/a.dart
lib/data/b.dart
lib/core/c.dart
''';
    final tool = AnalyzeArchitectureDriftTool(_MockRwGit(logOutput: logOut));
    final res = await tool.execute({
      'directory': '.',
      'layer_patterns': {
        'core': 'lib/core/',
        'ui': 'lib/ui/',
        'data': 'lib/data/',
      }
    });

    final data = jsonDecode(res) as Map<String, dynamic>;
    final smells = data['architectural_smells'] as List<dynamic>;
    expect(smells.any((s) => (s as Map)['type'] == 'Scattered Functionality'),
        isTrue);
  });
}
