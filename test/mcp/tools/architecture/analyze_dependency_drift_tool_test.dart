// ignore_for_file: avoid_dynamic_calls
import 'dart:convert';
import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

class _MockRunner implements ProcessRunner {
  final String lsTreeOutput;
  final Map<String, String> fileContents;

  _MockRunner({
    required this.lsTreeOutput,
    this.fileContents = const {},
  });

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
  });
}
