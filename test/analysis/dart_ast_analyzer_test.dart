import 'package:test/test.dart';
import 'package:rw_git/src/intelligence/static_analysis/dart/dart_ast_analyzer.dart';

void main() {
  test('DartAstAnalyzer', () {
    final analyzer = DartAstAnalyzer();
    final result = analyzer.analyzeFile('test.dart', '''
      class Test {
        void publicMethod() {
          print('hello');
        }
        void _privateMethod() {}
      }
      void globalFunction() {}
      void _privateGlobal() {}
    ''');
    expect(result.apiSignatures, contains('class Test'));
    expect(result.apiSignatures, contains('Test.void publicMethod()'));
    expect(result.internalMethods, contains('Test.void _privateMethod()'));
    expect(result.apiSignatures, contains('void globalFunction()'));
    expect(result.internalMethods, contains('void _privateGlobal()'));
    expect(result.invocations, contains('print'));
    expect(result.toJson()['api_signatures'], isNotEmpty);
  });

  group('detectImportCyclesInSources', () {
    final analyzer = DartAstAnalyzer();

    test('finds a cycle through relative and same-package imports', () {
      final cycles = analyzer.detectImportCyclesInSources({
        'lib/src/a.dart': "import 'b.dart';\nclass A {}",
        'lib/src/b.dart': "import 'package:demo/src/a.dart';\nclass B {}",
      }, packageName: 'demo');

      expect(cycles, hasLength(1));
      expect(cycles.single.toSet(), {'lib/src/a.dart', 'lib/src/b.dart'});
    });

    test('resolves ../ imports against the importing file directory', () {
      final cycles = analyzer.detectImportCyclesInSources({
        'lib/src/deep/a.dart': "import '../b.dart';\nclass A {}",
        'lib/src/b.dart': "import 'deep/a.dart';\nclass B {}",
      });

      expect(cycles, hasLength(1));
    });

    test('acyclic imports and foreign packages produce no cycles', () {
      final cycles = analyzer.detectImportCyclesInSources({
        'lib/a.dart':
            "import 'dart:io';\nimport 'package:test/test.dart';\n"
            "import 'b.dart';\nclass A {}",
        'lib/b.dart': 'class B {}',
      }, packageName: 'demo');

      expect(cycles, isEmpty);
    });

    test('unparseable sources are skipped, not fatal', () {
      final cycles = analyzer.detectImportCyclesInSources({
        'lib/broken.dart': 'class {{{',
        'lib/ok.dart': 'class Ok {}',
      });

      expect(cycles, isEmpty);
    });
  });
}
