import 'package:test/test.dart';
import 'package:rw_git/src/models/advanced_code_quality_dto.dart';

void main() {
  test('AdvancedCodeQualityDto toJson', () {
    final dto = AdvancedCodeQualityDto(
        fileComplexity: {}, coChangeMatrix: {}, architectureDistribution: {});
    expect(dto.toJson(), isNotNull);
  });
}
