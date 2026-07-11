import 'package:test/test.dart';
import 'package:rw_git/src/intelligence/static_analysis/metrics/agnostic/lexer/fsm_lexer.dart';
import 'package:rw_git/src/intelligence/static_analysis/metrics/agnostic/lexer/lexical_profile.dart';
import 'package:rw_git/src/intelligence/static_analysis/metrics/agnostic/lexer/token.dart';

void main() {
  group('FsmLexer number literals', () {
    test('keeps hexadecimal literals as a single number token', () {
      final tokens = FsmLexer('0x1A').tokenize();
      expect(tokens.length, 1);
      expect(tokens[0].type, TokenType.number);
      expect(tokens[0].lexeme, '0x1A');
    });
    test('keeps binary and octal literals as single number tokens', () {
      expect(FsmLexer('0b1010').tokenize()[0].lexeme, '0b1010');
      expect(FsmLexer('0o755').tokenize()[0].lexeme, '0o755');
    });
    test('keeps scientific notation as a single number token', () {
      expect(FsmLexer('1e5').tokenize()[0].lexeme, '1e5');
      expect(FsmLexer('1.5e-3').tokenize()[0].lexeme, '1.5e-3');
      expect(FsmLexer('2E+10').tokenize()[0].lexeme, '2E+10');
    });
    test('keeps digit separators inside a number token', () {
      expect(FsmLexer('1_000_000').tokenize()[0].lexeme, '1_000_000');
    });
    test('does not consume a trailing method-call dot', () {
      final tokens = FsmLexer('1.toString()').tokenize();
      expect(tokens[0].lexeme, '1');
      expect(tokens[0].type, TokenType.number);
      expect(tokens[1].lexeme, '.');
      expect(tokens[2].lexeme, 'toString');
    });
    test('does not treat a unit suffix as an exponent', () {
      final tokens = FsmLexer('1em').tokenize();
      expect(tokens[0].lexeme, '1');
      expect(tokens[1].lexeme, 'em');
    });
  });

  group('FsmLexer with injected LexicalProfile', () {
    test('Python: floor division is not a comment', () {
      final tokens = FsmLexer('a // b', LexicalProfile.python).tokenize();
      expect(tokens.map((t) => t.lexeme), ['a', '//', 'b']);
    });
    test('Python: # still masks comments', () {
      final tokens = FsmLexer('x = 1 # note', LexicalProfile.python).tokenize();
      expect(tokens.map((t) => t.lexeme), ['x', '=', '1']);
    });
    test('Python: triple-quoted strings mask interior quotes', () {
      final tokens = FsmLexer(
        '"""it "quotes" here""" x',
        LexicalProfile.python,
      ).tokenize();
      expect(tokens.map((t) => t.lexeme), ['x']);
    });
    test('C: preprocessor directives tokenize as code', () {
      final tokens = FsmLexer(
        '#include <stdio.h>\nint x;',
        LexicalProfile.cLike,
      ).tokenize();
      expect(tokens.any((t) => t.lexeme == 'include'), isTrue);
      expect(tokens.any((t) => t.lexeme == 'int'), isTrue);
    });
    test('Lua: block comments are masked', () {
      final tokens = FsmLexer(
        '--[[ if x then end ]] y = 1',
        LexicalProfile.lua,
      ).tokenize();
      expect(tokens.map((t) => t.lexeme), ['y', '=', '1']);
    });
    test('Lua: line comments are masked', () {
      final tokens = FsmLexer(
        'x = 1 -- note\ny = 2',
        LexicalProfile.lua,
      ).tokenize();
      expect(tokens.any((t) => t.lexeme == 'note'), isFalse);
      expect(tokens.any((t) => t.lexeme == 'y'), isTrue);
    });
    test('Ruby: =begin/=end block comments are masked', () {
      final tokens = FsmLexer(
        '=begin\nif x\n=end\nz = 1',
        LexicalProfile.ruby,
      ).tokenize();
      expect(tokens.any((t) => t.lexeme == 'if'), isFalse);
      expect(tokens.any((t) => t.lexeme == 'z'), isTrue);
    });
    test('Go: raw backtick strings do not treat backslash as escape', () {
      final tokens = FsmLexer(r'`C:\path\` + x', LexicalProfile.go).tokenize();
      expect(tokens.map((t) => t.lexeme), ['+', 'x']);
    });
    test('Dart: # is not a comment (symbols survive)', () {
      final tokens = FsmLexer('#symbol', LexicalProfile.dart).tokenize();
      expect(tokens.any((t) => t.lexeme == 'symbol'), isTrue);
    });
    test('default profile preserves permissive c-family behavior', () {
      final tokens = FsmLexer('x # comment').tokenize();
      expect(tokens.map((t) => t.lexeme), ['x']);
    });
  });

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
    test('handles backtick string', () {
      final lexer = FsmLexer('`hello` x');
      final tokens = lexer.tokenize();
      expect(tokens[0].lexeme, 'x');
    });
    test('handles newline explicitly', () {
      final lexer = FsmLexer('\n x');
      final tokens = lexer.tokenize();
      expect(tokens[0].type, TokenType.newline);
    });
    test('handles alphanumeric identifier', () {
      final lexer = FsmLexer('x123');
      final tokens = lexer.tokenize();
      expect(tokens[0].lexeme, 'x123');
      expect(tokens[0].type, TokenType.identifier);
    });
    test('handles numbers with decimals', () {
      final lexer = FsmLexer('123.456');
      final tokens = lexer.tokenize();
      expect(tokens[0].lexeme, '123.456');
      expect(tokens[0].type, TokenType.number);
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
        ['int', 'x', 'int', 'y'],
      );
      expect(tokens.any((t) => t.lexeme.contains('comment')), isFalse);
    });

    test('Masks block comments properly', () {
      final lexer = FsmLexer('/* \n * Block comment \n */\nclass Test {}');
      final tokens = lexer.tokenize();

      expect(
        tokens
            .where((t) => t.type == TokenType.identifier)
            .map((t) => t.lexeme),
        ['class', 'Test'],
      );
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

      final operators = tokens
          .where((t) => t.type == TokenType.operator)
          .toList();
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
