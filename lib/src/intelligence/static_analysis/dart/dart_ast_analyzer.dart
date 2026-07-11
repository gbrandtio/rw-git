import 'dart:math';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

class AstAnalysisResult {
  final Map<String, List<String>> dependencies;
  final List<String> apiSignatures;
  final List<String> internalMethods;
  final List<String> invocations;

  /// Relative import paths extracted from this file's import directives.
  final List<String> imports;

  AstAnalysisResult({
    required this.dependencies,
    required this.apiSignatures,
    required this.internalMethods,
    required this.invocations,
    required this.imports,
  });

  Map<String, dynamic> toJson() {
    return {
      'dependencies': dependencies,
      'api_signatures': apiSignatures,
      'internal_methods': internalMethods,
      'invocations': invocations,
      'imports': imports,
    };
  }
}

/// Detects circular import groups using Tarjan's Strongly Connected Components
/// algorithm (Tarjan, 1972). Only returns SCCs of size > 1 (actual cycles).
///
/// The internal `v`/`w` node identifiers below follow the standard notation
/// used in the graph-algorithm literature for this algorithm, rather than
/// this codebase's usual descriptive-naming convention.
List<List<String>> _tarjanScc(Map<String, List<String>> graph) {
  final indices = <String, int>{};
  final lowlinks = <String, int>{};
  final onStack = <String, bool>{};
  final stack = <String>[];
  final sccs = <List<String>>[];
  int index = 0;

  void strongConnect(String v) {
    indices[v] = index;
    lowlinks[v] = index;
    index++;
    stack.add(v);
    onStack[v] = true;

    for (final w in graph[v] ?? <String>[]) {
      if (!indices.containsKey(w)) {
        strongConnect(w);
        lowlinks[v] = min(lowlinks[v]!, lowlinks[w]!);
      } else if (onStack[w] == true) {
        lowlinks[v] = min(lowlinks[v]!, indices[w]!);
      }
    }

    if (lowlinks[v] == indices[v]) {
      final scc = <String>[];
      String w;
      do {
        w = stack.removeLast();
        onStack[w] = false;
        scc.add(w);
      } while (w != v);
      if (scc.length > 1) sccs.add(scc);
    }
  }

  for (final v in graph.keys) {
    if (!indices.containsKey(v)) strongConnect(v);
  }

  return sccs;
}

class _AstVisitor extends RecursiveAstVisitor<void> {
  final Map<String, List<String>> dependencies = {};
  final List<String> apiSignatures = [];
  final List<String> internalMethods = [];
  final List<String> invocations = [];
  final List<String> imports = [];

  String? _currentClass;

  @override
  void visitImportDirective(ImportDirective node) {
    final uri = node.uri.stringValue;
    if (uri != null) imports.add(uri);
    super.visitImportDirective(node);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _currentClass = node.classKeyword.next?.lexeme ?? 'UnknownClass';
    apiSignatures.add('class $_currentClass');
    super.visitClassDeclaration(node);
    _currentClass = null;
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final retType = node.returnType?.toSource() ?? 'dynamic';
    final name = node.name.lexeme;
    final params = node.parameters?.toSource() ?? '()';
    final signature = '$retType $name$params';
    final prefix = _currentClass != null ? '$_currentClass.' : '';

    if (name.startsWith('_')) {
      internalMethods.add('$prefix$signature');
    } else {
      apiSignatures.add('$prefix$signature');
    }
    super.visitMethodDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    final retType = node.returnType?.toSource() ?? 'dynamic';
    final name = node.name.lexeme;
    final params = node.functionExpression.parameters?.toSource() ?? '()';
    final signature = '$retType $name$params';

    if (name.startsWith('_')) {
      internalMethods.add(signature);
    } else {
      apiSignatures.add(signature);
    }
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target?.toSource() ?? 'this';
    final method = node.methodName.name;
    dependencies.putIfAbsent(target, () => []).add(method);
    invocations.add(method);
    super.visitMethodInvocation(node);
  }
}

class DartAstAnalyzer {
  AstAnalysisResult analyzeFile(String filePath, String content) {
    final parseResult = parseString(
      content: content,
      throwIfDiagnostics: false,
    );
    final visitor = _AstVisitor();
    parseResult.unit.visitChildren(visitor);

    return AstAnalysisResult(
      dependencies: visitor.dependencies,
      apiSignatures: visitor.apiSignatures,
      internalMethods: visitor.internalMethods,
      invocations: visitor.invocations,
      imports: visitor.imports,
    );
  }

  /// Detects circular import chains across a set of analyzed files.
  ///
  /// [fileImports] maps each file path to the list of import URIs it declares.
  /// Only relative imports (starting with `..` or not starting with `package:`,
  /// `dart:`) are considered, since package/sdk imports cannot be circular within
  /// a single project analysis.
  List<List<String>> detectImportCycles(Map<String, List<String>> fileImports) {
    final graph = <String, List<String>>{};

    for (final entry in fileImports.entries) {
      final file = entry.key;
      final targets = entry.value
          .where((u) => !u.startsWith('package:') && !u.startsWith('dart:'))
          .toList();
      graph[file] = targets;
    }

    return _tarjanScc(graph);
  }

  /// Parses [dartSources] (repo-relative path -> source text) and detects
  /// circular import chains among them via Tarjan's SCC (Tarjan 1972).
  ///
  /// Unlike [detectImportCycles], import URIs are first resolved to
  /// repo-relative paths so both relative imports and same-package
  /// `package:` imports (rewritten to `lib/...` when [packageName] is
  /// given) participate in the graph. Used by the report meta-tools on the
  /// bounded top-churn sample; sources that fail to parse are skipped
  /// rather than failing the report.
  List<List<String>> detectImportCyclesInSources(
    Map<String, String> dartSources, {
    String? packageName,
  }) {
    final fileImports = <String, List<String>>{};
    for (final entry in dartSources.entries) {
      final List<String> rawImports;
      try {
        rawImports = analyzeFile(entry.key, entry.value).imports;
      } catch (_) {
        continue;
      }
      fileImports[entry.key] = rawImports
          .map(
            (uri) => _resolveImportToRepoPath(entry.key, uri, packageName),
          )
          .whereType<String>()
          .toList();
    }
    return _tarjanScc(fileImports);
  }

  /// Resolves an import [uri] declared in [importingFile] to a
  /// repo-relative path, or null when it cannot point inside the repo
  /// (SDK imports, other packages).
  static String? _resolveImportToRepoPath(
    String importingFile,
    String uri,
    String? packageName,
  ) {
    if (uri.startsWith('dart:')) return null;
    if (uri.startsWith('package:')) {
      if (packageName == null) return null;
      final prefix = 'package:$packageName/';
      if (!uri.startsWith(prefix)) return null;
      return 'lib/${uri.substring(prefix.length)}';
    }
    // Relative import: resolve against the importing file's directory.
    final baseSegments = importingFile.split('/')..removeLast();
    for (final segment in uri.split('/')) {
      if (segment == '.' || segment.isEmpty) continue;
      if (segment == '..') {
        if (baseSegments.isEmpty) return null;
        baseSegments.removeLast();
      } else {
        baseSegments.add(segment);
      }
    }
    return baseSegments.join('/');
  }
}
