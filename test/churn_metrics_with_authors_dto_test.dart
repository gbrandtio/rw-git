import 'package:rw_git/src/models/churn_metrics_with_authors_dto.dart';
import 'package:test/test.dart';

void main() {
  group('ChurnMetricsWithAuthorsDto', () {
    test('empty constructor returns object with length 0', () {
      final dto = ChurnMetricsWithAuthorsDto.empty();
      expect(dto.fileChurn.isEmpty, true);
      expect(dto.classChurn.isEmpty, true);
      expect(dto.blockChurn.isEmpty, true);
      expect(dto.totalCommits, 0);
    });
  });
}
