import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

void main() {
  /// Test group for ShortStatDto
  group('ShortStatDto', () {
    test('will not have null properties when initialized', () async {
      ShortStatDto shortStatDto = ShortStatDto(10, 20, 30);
      expect(shortStatDto.numberOfChangedFiles, 10);
      expect(shortStatDto.deletions, 20);
      expect(shortStatDto.insertions, 30);
    });
  });
}
