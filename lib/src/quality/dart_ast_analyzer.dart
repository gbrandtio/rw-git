import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

class AstAnalysisResult {
  final Map<String, List<String>> dependencies;
  final List<String> apiSignatures;
  final List<String> internalMethods;
  final List<String> invocations;

  AstAnalysisResult({
    required this.dependencies,
    required this.apiSignatures,
    required this.internalMethods,
    required this.invocations,
  });

  Map<String, dynamic> toJson() {
    return {
      'dependencies': dependencies,
      'api_signatures': apiSignatures,
      'internal_methods': internalMethods,
      'invocations': invocations,
    };
  }
}

class _AstVisitor extends RecursiveAstVisitor<void> {
  final Map<String, List<String>> dependencies = {};
  final List<String> apiSignatures = [];
  final List<String> internalMethods = [];
  final List<String> invocations = [];

  String? _currentClass;

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
    final parseResult =
        parseString(content: content, throwIfDiagnostics: false);
    final visitor = _AstVisitor();
    parseResult.unit.visitChildren(visitor);

    return AstAnalysisResult(
      dependencies: visitor.dependencies,
      apiSignatures: visitor.apiSignatures,
      internalMethods: visitor.internalMethods,
      invocations: visitor.invocations,
    );
  }
}
