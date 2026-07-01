import 'package:rw_git/src/core/git_date_time.dart';
import 'package:test/test.dart';

void main() {
  group('GitDateTime', () {
    test('parses iso-strict (%aI) timestamps preserving the offset', () {
      final parsed = GitDateTime.parse('2026-06-29T00:15:30+04:00');

      expect(parsed.offset, equals(const Duration(hours: 4)));
      expect(parsed.utc, equals(DateTime.utc(2026, 6, 28, 20, 15, 30)));
    });

    test('authorLocal exposes the author wall-clock fields', () {
      final parsed = GitDateTime.parse('2026-06-29T23:15:30+04:00');

      // The instant is 19:15 UTC, but the author committed at 23:15 locally;
      // burnout-style metrics must see the author's hour.
      expect(parsed.utc.hour, equals(19));
      expect(parsed.authorLocal.hour, equals(23));
      expect(parsed.authorLocal.day, equals(29));
    });

    test('parses blame-style space-separated timestamps', () {
      final parsed = GitDateTime.parse('2026-06-29 00:00:00 +0400');

      expect(parsed.offset, equals(const Duration(hours: 4)));
      expect(parsed.utc, equals(DateTime.utc(2026, 6, 28, 20)));
      expect(parsed.authorLocal.hour, equals(0));
    });

    test('handles negative offsets and Z', () {
      final negative = GitDateTime.parse('2026-06-29T01:00:00-05:30');
      expect(negative.offset, equals(const Duration(hours: -5, minutes: -30)));
      expect(negative.utc, equals(DateTime.utc(2026, 6, 29, 6, 30)));

      final zulu = GitDateTime.parse('2026-06-29T01:00:00Z');
      expect(zulu.offset, equals(Duration.zero));
      expect(zulu.utc, equals(DateTime.utc(2026, 6, 29, 1)));
    });

    test('throws instead of falling back on malformed input', () {
      expect(() => GitDateTime.parse('not a date'),
          throwsA(isA<FormatException>()));
      // A timestamp without an offset is rejected: silently assuming a
      // timezone is exactly the corruption this parser exists to prevent.
      expect(() => GitDateTime.parse('2026-06-29T00:00:00'),
          throwsA(isA<FormatException>()));
    });
  });
}
