import 'package:test/test.dart';
import 'package:rw_git/src/models/logical_coupling_dto.dart';

void main() {
  test('LogicalCouplingDto toJson', () {
    final dto = LogicalCouplingDto(
      fileA: 'a',
      fileB: 'b',
      coChangeCount: 1,
      confidence: 1.0,
    );
    expect(dto.toJson(), isNotNull);
  });
}
