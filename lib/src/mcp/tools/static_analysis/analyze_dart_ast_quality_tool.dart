import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:path/path.dart' as p;
import '../../../../rw_git.dart';
import '../../utils/mcp_argument_extensions.dart';

class AnalyzeDartAstQualityTool implements McpTool {
  final RwGit rwGit;

  AnalyzeDartAstQualityTool(this.rwGit);

  @override
  String get name => 'analyze_dart_ast_quality';

  @override
  String get description =>
      'Performs deep AST-level analysis of Dart files modified between two branches. '
      'Returns a dependency graph, semantic signature diff, and dead code audit for the touched files. '
      'Strictly scoped to a maximum of 10 files to prevent performance degradation.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'directory': {
            'type': 'string',
            'description': 'The local repository path.',
          },
          'baseBranch': {
            'type': 'string',
            'description': 'The base branch to compare against.',
          },
          'targetBranch': {
            'type': 'string',
            'description': 'The target branch with changes.',
          },
        },
        'required': ['directory', 'baseBranch', 'targetBranch'],
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments.getStringArgument('directory');
    final baseBranch = arguments.getStringArgument('baseBranch');
    final targetBranch = arguments.getStringArgument('targetBranch');

    // 1. Get changed files
    final mergeBaseRes = await rwGit
        .runCommand(directory, ['merge-base', baseBranch, targetBranch]);
    final mergeBase = mergeBaseRes.getOrNull()?.trim() ?? '';

    if (mergeBase.isEmpty) {
      return jsonEncode({
        'error':
            'Could not determine merge base between $baseBranch and $targetBranch'
      });
    }

    final diffRes = await rwGit.runCommand(
        directory, ['diff', '--name-only', mergeBase, targetBranch]);
    final changedFiles = (diffRes.getOrNull()?.trim() ?? '')
        .split('\n')
        .where((f) => f.endsWith('.dart'))
        .toList();

    if (changedFiles.isEmpty) {
      return jsonEncode({
        'message':
            'No Dart files modified between $baseBranch and $targetBranch'
      });
    }

    // 2. Enforce scoping constraints
    if (changedFiles.length > 10) {
      return jsonEncode({
        'error':
            'Scope constraint exceeded. Refusing to parse more than 10 Dart files simultaneously.',
        'files_count': changedFiles.length,
      });
    }

    // 3. Extract file contents and run AST parser via Isolate to prevent blocking
    final canonicalDir = p.canonicalize(directory);
    final Map<String, String> filesContent = {};
    for (final file in changedFiles) {
      final resolvedPath = p.canonicalize(p.join(directory, file));
      if (!p.isWithin(canonicalDir, resolvedPath)) continue;
      final sourceFile = File(resolvedPath);
      if (await sourceFile.exists()) {
        filesContent[file] = await sourceFile.readAsString();
      }
    }

    if (filesContent.isEmpty) {
      return jsonEncode(
          {'message': 'No valid Dart files found on disk to parse.'});
    }

    // Run heavy AST parsing in a background Isolate
    final analysisResults =
        await Isolate.run(() => _runAstAnalysis(filesContent));

    // Collect per-file imports for cycle detection.
    final fileImports = <String, List<String>>{};
    for (final entry in analysisResults.entries) {
      final perFile = entry.value as Map<String, dynamic>?;
      if (perFile != null && perFile.containsKey('imports')) {
        fileImports[entry.key] =
            List<String>.from(perFile['imports'] as List<dynamic>? ?? []);
      }
    }
    final cycles = DartAstAnalyzer().detectImportCycles(fileImports);

    return jsonEncode({
      'files_analyzed': filesContent.keys.toList(),
      'ast_analysis': analysisResults,
      'import_cycles': cycles,
      'guidance': [
        'Use the "dependencies" graph to verify that layers are isolated properly (e.g. UI should not depend on DB direct access).',
        'Check "api_signatures" for unintended breaking changes to public interfaces.',
        'Use "internal_methods" and "invocations" to audit for dead code. If an internal method is never invoked in the same file or its dependencies, it might be dead code.',
        'If "import_cycles" is non-empty, the listed files form circular import chains. Break cycles by extracting shared types into a separate module.',
      ]
    });
  }

  static Map<String, dynamic> _runAstAnalysis(
      Map<String, String> filesContent) {
    final analyzer = DartAstAnalyzer();
    final Map<String, dynamic> results = {};

    for (final entry in filesContent.entries) {
      final fileName = entry.key;
      final content = entry.value;

      try {
        final res = analyzer.analyzeFile(fileName, content);
        results[fileName] = res.toJson();
      } catch (e) {
        results[fileName] = {'error': e.toString()};
      }
    }

    return results;
  }
}
