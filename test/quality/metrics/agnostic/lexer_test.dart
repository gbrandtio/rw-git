import 'package:test/test.dart';
import 'package:rw_git/src/quality/metrics/agnostic/lexer/fsm_lexer.dart';
import 'package:rw_git/src/quality/metrics/agnostic/lexer/token.dart';

void main() {
  group('FsmLexer coverage additions', () {
    test('handles unknown chars', () {
      final lexer = FsmLexer('@');
      final tokens = lexer.tokenize();
      expect(tokens[0].type, TokenType.unknown);
    });
    test('handles HTML comments', () {
      final lexer = FsmLexer('<!-- comment --> int x;');
      final tokens = lexer.tokenize();
      expect(tokens[0].lexeme, 'int');
    });
    test('handles end of file comment hash', () {
      final lexer = FsmLexer('x #');
      final tokens = lexer.tokenize();
      expect(tokens[0].lexeme, 'x');
    });
    test('handles escape in string', () {
      final lexer = FsmLexer(r'"hello \" world" x');
      final tokens = lexer.tokenize();
      expect(tokens[0].lexeme, 'x');
    });
    test('handles single line comment hash', () {
      final lexer = FsmLexer('# comment \n x');
      final tokens = lexer.tokenize();
      expect(tokens.length, greaterThan(0));
    });
  });

  group('FsmLexer', () {
    test('Tokenizes basic identifiers and punctuation', () {
      final lexer = FsmLexer('void main() { }');
      final tokens = lexer.tokenize();

      expect(tokens.length, 6);
      expect(tokens[0].lexeme, 'void');
      expect(tokens[0].type, TokenType.identifier);

      expect(tokens[1].lexeme, 'main');
      expect(tokens[1].type, TokenType.identifier);

      expect(tokens[2].lexeme, '(');
      expect(tokens[2].type, TokenType.punctuation);

      expect(tokens[3].lexeme, ')');
      expect(tokens[4].lexeme, '{');
      expect(tokens[5].lexeme, '}');
    });

    test('Masks inline comments properly', () {
      final lexer = FsmLexer('int x = 5; // This is a comment\nint y = 6;');
      final tokens = lexer.tokenize();

      // Should be: int, x, =, 5, ;, \n, int, y, =, 6, ;
      expect(
          tokens
              .where((t) => t.type == TokenType.identifier)
              .map((t) => t.lexeme),
          ['int', 'x', 'int', 'y']);
      expect(tokens.any((t) => t.lexeme.contains('comment')), isFalse);
    });

    test('Masks block comments properly', () {
      final lexer = FsmLexer('/* \n * Block comment \n */\nclass Test {}');
      final tokens = lexer.tokenize();

      expect(
          tokens
              .where((t) => t.type == TokenType.identifier)
              .map((t) => t.lexeme),
          ['class', 'Test']);
      expect(tokens.any((t) => t.lexeme.contains('Block')), isFalse);
    });

    test('Masks string literals properly', () {
      final lexer = FsmLexer('String a = "Hello // world";');
      final tokens = lexer.tokenize();

      // String literal itself is masked entirely, it won't emit a token for it
      expect(tokens.length, 4); // String, a, =, ;
      expect(tokens[0].lexeme, 'String');
      expect(tokens[1].lexeme, 'a');
      expect(tokens[2].lexeme, '=');
      expect(tokens[3].lexeme, ';');
    });

    test('Handles composite operators', () {
      final lexer = FsmLexer('a === b && c >= d;');
      final tokens = lexer.tokenize();

      final operators =
          tokens.where((t) => t.type == TokenType.operator).toList();
      expect(operators.length, 3);
      expect(operators[0].lexeme, '===');
      expect(operators[1].lexeme, '&&');
      expect(operators[2].lexeme, '>=');
    });

    test('Zero allocation tokenization validates substring boundaries', () {
      const source = 'fn(123)';
      final lexer = FsmLexer(source);
      final tokens = lexer.tokenize();

      expect(tokens[0].start, 0);
      expect(tokens[0].end, 2);

      expect(tokens[1].start, 2);
      expect(tokens[1].end, 3);

      expect(tokens[2].start, 3);
      expect(tokens[2].end, 6);
    });
  });
}
