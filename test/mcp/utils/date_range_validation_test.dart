import 'package:rw_git/src/mcp/utils/date_range_validation.dart';
import 'package:test/test.dart';

void main() {
  group('isValidDateInput', () {
    test('accepts ISO-8601 dates', () {
      expect(isValidDateInput('2024-01-01'), isTrue);
      expect(isValidDateInput('2024-12-31'), isTrue);
    });

    test('accepts git relative-date phrases for every unit, singular and '
        'plural', () {
      const units = [
        'second',
        'minute',
        'hour',
        'day',
        'week',
        'month',
        'year',
      ];
      for (final unit in units) {
        expect(isValidDateInput('1 $unit ago'), isTrue, reason: unit);
        expect(isValidDateInput('2 ${unit}s ago'), isTrue, reason: unit);
      }
    });

    test('accepts "yesterday" case-insensitively', () {
      expect(isValidDateInput('yesterday'), isTrue);
      expect(isValidDateInput('Yesterday'), isTrue);
      expect(isValidDateInput('YESTERDAY'), isTrue);
    });

    test('rejects malformed or unrecognized input', () {
      expect(isValidDateInput(''), isFalse);
      expect(isValidDateInput('not-a-date'), isFalse);
      expect(isValidDateInput('tomorrow'), isFalse);
      expect(isValidDateInput('-n'), isFalse);
      expect(isValidDateInput('--exec=rm'), isFalse);
    });
  });
}
