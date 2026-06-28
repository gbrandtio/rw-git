import 'package:test/test.dart';
import 'package:rw_git/src/quality/dart_ast_analyzer.dart';

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
}
