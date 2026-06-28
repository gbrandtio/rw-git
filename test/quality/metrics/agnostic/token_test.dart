import 'package:test/test.dart';
import 'package:rw_git/src/quality/metrics/agnostic/lexer/token.dart';

void main() {
  test('Token toString', () {
    final token = Token(type: TokenType.identifier, start: 0, end: 4, source: 'test');
    expect(token.toString(), 'Token(TokenType.identifier, "test")');
  });
}
