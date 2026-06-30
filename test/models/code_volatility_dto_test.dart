import 'package:test/test.dart';
import 'package:rw_git/src/models/code_volatility_dto.dart';

void main() {
  test('CodeVolatilityDto toJson', () {
    final dto = CodeVolatilityDto(
        filePath: 'a', totalChanges: 1, uniqueAuthors: 1, volatilityScore: 1.0);
    expect(dto.toJson(), isNotNull);
  });
}
