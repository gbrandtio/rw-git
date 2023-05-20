import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

void main() {
  /// Test group for ShortStatDto
  group('ShortStatDto', () {
    test('will not have null properties when initialized', () async {
      ShortStatDto shortStatDto = ShortStatDto(10, 20, 30);
      expect(shortStatDto.numberOfChangedFiles, 10);
      expect(shortStatDto.insertions, 20);
      expect(shortStatDto.deletions, 30);
    });

    test('will have the default values', () async {
      ShortStatDto shortStatDto = ShortStatDto.defaultStats();
      expect(shortStatDto.numberOfChangedFiles, -1);
      expect(shortStatDto.insertions, -1);
      expect(shortStatDto.deletions, -1);
    });
  });
}
