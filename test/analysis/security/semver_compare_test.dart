import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

void main() {
  group('classifyFreshness', () {
    test('exact match is current', () {
      expect(classifyFreshness('1.2.3', '1.2.3'), 'current');
    });

    test('declared ahead of latest is current', () {
      expect(classifyFreshness('2.0.0', '1.9.9'), 'current');
    });

    test('patch behind', () {
      expect(classifyFreshness('1.2.3', '1.2.4'), 'patch_behind');
    });

    test('minor behind', () {
      expect(classifyFreshness('1.2.3', '1.3.0'), 'minor_behind');
    });

    test('major behind', () {
      expect(classifyFreshness('1.2.3', '2.0.0'), 'major_behind');
    });

    test('strips caret specifier before comparing', () {
      expect(classifyFreshness('^1.2.3', '1.2.3'), 'current');
    });

    test('strips tilde specifier before comparing', () {
      expect(classifyFreshness('~1.2.3', '1.2.4'), 'patch_behind');
    });

    test('strips v prefix before comparing', () {
      expect(classifyFreshness('v1.2.3', '1.2.3'), 'current');
    });

    test('pre-release tags are unknown', () {
      expect(classifyFreshness('1.2.3-beta.1', '2.0.0'), 'unknown');
    });

    test('"any" is unknown', () {
      expect(classifyFreshness('any', '1.0.0'), 'unknown');
    });

    test('git/path dependencies are unknown', () {
      expect(classifyFreshness('git:something', '1.0.0'), 'unknown');
    });

    test('unparsable latest version is unknown', () {
      expect(classifyFreshness('1.2.3', 'not-a-version'), 'unknown');
    });
  });
}
