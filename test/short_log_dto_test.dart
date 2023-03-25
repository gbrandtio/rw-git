import 'package:rw_git/rw_git.dart';
import 'package:rw_git/src/models/short_log_dto.dart';
import 'package:test/test.dart';

void main() {
  /// Test group for ShortLogDto
  group('ShortLogDto', () {
    test('will not have null properties when initialized', () async {
      ShortLogDto shortStatDto = ShortLogDto(10, "Test Author Name");
      expect(shortStatDto.numberOfContributions, 10);
      expect(shortStatDto.authorName, "Test Author Name");
    });
  });
}
