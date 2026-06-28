import 'package:test/test.dart';
import 'package:rw_git/src/quality/metrics/models.dart';

void main() {
  test('HalsteadResult toJson', () {
    final result = HalsteadResult(
      vocabulary: 1, length: 2, volume: 3.0, difficulty: 4.0, effort: 5.0, timeRequired: 6.0, deliveredBugs: 7.0,
    );
    expect(result.toJson()['vocabulary'], 1);
  });

  test('MaintainabilityResult toJson', () {
    final result = MaintainabilityResult(score: 1.0, category: 'Good');
    expect(result.toJson()['score'], 1.0);
  });
}
