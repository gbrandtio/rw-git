import 'package:test/test.dart';
import 'package:rw_git/src/models/bus_factor_dto.dart';

void main() {
  test('BusFactorDto toJson', () {
    final dto = BusFactorDto(
      busFactor: 1,
      totalDevelopers: 1,
      topContributors: [],
    );
    expect(dto.toJson(), isNotNull);
  });
}
