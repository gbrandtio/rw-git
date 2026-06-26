// ignore_for_file: avoid_dynamic_calls, unnecessary_cast
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

void main() {
  group('ChurnMetricsDto', () {
    test('empty constructor returns maps with length 0', () {
      final dto = ChurnMetricsDto.empty();
      expect(dto.fileChurn.isEmpty, true);
      expect(dto.classChurn.isEmpty, true);
      expect(dto.blockChurn.isEmpty, true);
      expect(dto.totalCommits, 0);
    });

    test('will retain properties when initialized', () {
      final dto = const ChurnMetricsDto(
        fileChurn: {'main.dart': 5},
        classChurn: {'RwGit': 3},
        blockChurn: {'fetchTags': 2},
        totalCommits: 10,
      );

      expect(dto.fileChurn['main.dart'], 5);
      expect(dto.classChurn['RwGit'], 3);
      expect(dto.blockChurn['fetchTags'], 2);
      expect(dto.totalCommits, 10);
    });
  });
}
