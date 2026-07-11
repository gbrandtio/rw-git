// ignore_for_file: avoid_dynamic_calls
import 'dart:convert';
import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

class _MockRunner implements ProcessRunner {
  final String lsTreeOutput;
  final Map<String, String> fileContents;

  _MockRunner({required this.lsTreeOutput, this.fileContents = const {}});

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool streamOutput = false,
  }) async {
    if (arguments.contains('ls-tree')) {
      return ProcessResult(0, 0, lsTreeOutput, '');
    }
    if (arguments.contains('show')) {
      final ref = arguments.last;
      final path = ref.replaceFirst('HEAD:', '');
      final content = fileContents[path] ?? '';
      return ProcessResult(0, 0, content, '');
    }
    return ProcessResult(0, 0, '', '');
  }

  @override
  Stream<String> runStream(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async* {}
}

void main() {
  group('AnalyzeDependencyDriftTool', () {
    test('has correct name and schema', () {
      final runner = _MockRunner(lsTreeOutput: '');
      final tool = AnalyzeDependencyDriftTool(runner);

      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema.isNotEmpty, isTrue);
      expect(tool.name, 'analyze_dependency_drift');
      expect(tool.inputSchema['required'], contains('directory'));
    });

    test('analyzes pubspec.yaml pinned vs floating', () async {
      final lsTree = 'pubspec.yaml\npubspec.lock\nlib/main.dart';
      final pubspec = '''
name: my_app
dependencies:
  http: ^0.13.0
  path: 1.8.0
  test: any
dev_dependencies:
  lints: ^5.0.0
''';

      final runner = _MockRunner(
        lsTreeOutput: lsTree,
        fileContents: {'pubspec.yaml': pubspec},
      );
      final tool = AnalyzeDependencyDriftTool(runner);

      final result = await tool.execute({'directory': '/test'});
      final parsed = jsonDecode(result) as Map<String, dynamic>;

      expect(parsed['ecosystems'], isNotEmpty);
      final eco = (parsed['ecosystems'] as List).first;
      expect(eco['type'], 'dart');
      expect(eco['has_lock_file'], isTrue);
      expect(eco['total_dependencies'], greaterThan(0));
    });

    test('handles requirements.txt', () async {
      final lsTree = 'requirements.txt';
      final reqs = '''
flask==2.0.1
requests>=2.25.0
numpy
''';

      final runner = _MockRunner(
        lsTreeOutput: lsTree,
        fileContents: {'requirements.txt': reqs},
      );
      final tool = AnalyzeDependencyDriftTool(runner);

      final result = await tool.execute({'directory': '/test'});
      final parsed = jsonDecode(result) as Map<String, dynamic>;

      final eco = (parsed['ecosystems'] as List).first;
      expect(eco['type'], 'python');
      expect(eco['pinned_count'], 1);
      expect(eco['floating_count'], 2);
      expect(eco['has_lock_file'], isTrue);
    });

    test('reports none risk for no manifests', () async {
      final runner = _MockRunner(lsTreeOutput: 'src/main.dart');
      final tool = AnalyzeDependencyDriftTool(runner);

      final result = await tool.execute({'directory': '/test'});
      final parsed = jsonDecode(result) as Map<String, dynamic>;

      expect(parsed['overall_risk'], 'none');
      expect(parsed['total_dependencies'], 0);
    });

    test('increments missingLocks when lock file is missing', () async {
      final lsTree = 'pubspec.yaml';
      final pubspec = '''
name: my_app
dependencies:
  http: ^0.13.0
''';
      final runner = _MockRunner(
        lsTreeOutput: lsTree,
        fileContents: {'pubspec.yaml': pubspec},
      );
      final tool = AnalyzeDependencyDriftTool(runner);

      final result = await tool.execute({'directory': '/test'});
      final parsed = jsonDecode(result) as Map<String, dynamic>;

      final eco = (parsed['ecosystems'] as List).first;
      expect(eco['has_lock_file'], isFalse);
    });

    test('makes zero network calls when check_freshness is absent', () async {
      final lsTree = 'pubspec.yaml\npubspec.lock';
      final pubspec = '''
name: my_app
dependencies:
  http: ^0.13.0
''';
      final runner = _MockRunner(
        lsTreeOutput: lsTree,
        fileContents: {'pubspec.yaml': pubspec},
      );
      final httpClient = MockHttpClient(); // throws if any request is made
      final tool = AnalyzeDependencyDriftTool(runner, httpClient: httpClient);

      final result = await tool.execute({'directory': '/test'});
      final parsed = jsonDecode(result) as Map<String, dynamic>;

      expect(httpClient.capturedRequests, isEmpty);
      expect(parsed.containsKey('freshness_summary'), isFalse);
      final eco = (parsed['ecosystems'] as List).first as Map<String, dynamic>;
      expect(eco.containsKey('dependencies'), isFalse);
    });

    test('makes zero network calls when check_freshness is false', () async {
      final lsTree = 'pubspec.yaml';
      final pubspec = 'dependencies:\n  http: ^0.13.0\n';
      final runner = _MockRunner(
        lsTreeOutput: lsTree,
        fileContents: {'pubspec.yaml': pubspec},
      );
      final httpClient = MockHttpClient();
      final tool = AnalyzeDependencyDriftTool(runner, httpClient: httpClient);

      await tool.execute({'directory': '/test', 'check_freshness': false});

      expect(httpClient.capturedRequests, isEmpty);
    });

    test('check_freshness=true adds freshness data per dependency', () async {
      final lsTree = 'pubspec.yaml';
      final pubspec = '''
name: my_app
dependencies:
  path: 1.0.0
''';
      final runner = _MockRunner(
        lsTreeOutput: lsTree,
        fileContents: {'pubspec.yaml': pubspec},
      );
      final httpClient = MockHttpClient();
      httpClient.setMockResponse(
        'GET',
        Uri.parse('https://pub.dev/api/packages/path'),
        200,
        '{"latest":{"version":"1.9.1"}}',
      );
      final tool = AnalyzeDependencyDriftTool(runner, httpClient: httpClient);

      final result = await tool.execute({
        'directory': '/test',
        'check_freshness': true,
      });
      final parsed = jsonDecode(result) as Map<String, dynamic>;

      final eco = (parsed['ecosystems'] as List).first as Map<String, dynamic>;
      final deps = eco['dependencies'] as List;
      expect(deps, hasLength(1));
      final dep = deps.first as Map<String, dynamic>;
      expect(dep['name'], 'path');
      final freshness = dep['freshness'] as Map<String, dynamic>;
      expect(freshness['latest_version'], '1.9.1');
      expect(freshness['classification'], 'minor_behind');

      final summary = parsed['freshness_summary'] as Map<String, dynamic>;
      expect(summary['checked'], isTrue);
      expect(summary['minor_behind'], 1);
    });

    test(
      'a failed freshness lookup still returns a successful tool result',
      () async {
        final lsTree = 'pubspec.yaml';
        final pubspec = '''
name: my_app
dependencies:
  path: 1.0.0
  http: 1.0.0
''';
        final runner = _MockRunner(
          lsTreeOutput: lsTree,
          fileContents: {'pubspec.yaml': pubspec},
        );
        final httpClient = MockHttpClient();
        httpClient.setMockResponse(
          'GET',
          Uri.parse('https://pub.dev/api/packages/path'),
          200,
          '{"latest":{"version":"1.0.0"}}',
        );
        httpClient.setMockResponse(
          'GET',
          Uri.parse('https://pub.dev/api/packages/http'),
          500,
          'server error',
        );
        final tool = AnalyzeDependencyDriftTool(runner, httpClient: httpClient);

        final result = await tool.execute({
          'directory': '/test',
          'check_freshness': true,
        });
        final parsed = jsonDecode(result) as Map<String, dynamic>;

        final eco =
            (parsed['ecosystems'] as List).first as Map<String, dynamic>;
        final deps = (eco['dependencies'] as List).cast<Map<String, dynamic>>();
        final pathDep =
            deps.firstWhere((d) => d['name'] == 'path')['freshness']
                as Map<String, dynamic>;
        final httpDep =
            deps.firstWhere((d) => d['name'] == 'http')['freshness']
                as Map<String, dynamic>;

        expect(pathDep['classification'], 'current');
        expect(httpDep['classification'], 'unknown');
        expect(httpDep['error'], isNotNull);

        final summary = parsed['freshness_summary'] as Map<String, dynamic>;
        expect(summary['current'], 1);
        expect(summary['unknown'], 1);
      },
    );
  });
}
