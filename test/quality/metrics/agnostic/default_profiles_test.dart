import 'package:test/test.dart';
import 'package:rw_git/src/quality/metrics/agnostic/profiles/default_profiles.dart';

void main() {
  test('DefaultProfiles', () {
    final profile = DefaultProfiles.dart;
    expect(profile.name, 'Dart');
    expect(profile.isControlFlow('if'), isTrue);
    expect(profile.isControlFlow('hello'), isFalse);
    expect(profile.isStructuralAnchor('class'), isTrue);
    expect(profile.isStructuralAnchor('hello'), isFalse);
    expect(profile.isOperatorKeyword('as'), isTrue);
    expect(profile.isOperatorKeyword('hello'), isFalse);
  });
}
