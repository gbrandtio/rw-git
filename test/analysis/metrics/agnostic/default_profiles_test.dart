import 'package:test/test.dart';
import 'package:rw_git/src/intelligence/static_analysis/metrics/agnostic/profiles/default_profiles.dart';

void main() {
  group('DefaultProfiles', () {
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

    test('getProfileForFile returns correct profiles', () {
      expect(DefaultProfiles.getProfileForFile('test.dart').name, 'Dart');
      expect(DefaultProfiles.getProfileForFile('test.py').name, 'Python');
      expect(DefaultProfiles.getProfileForFile('test.js').name,
          'JavaScript/TypeScript');
      expect(DefaultProfiles.getProfileForFile('test.ts').name,
          'JavaScript/TypeScript');
      expect(DefaultProfiles.getProfileForFile('test.jsx').name,
          'JavaScript/TypeScript');
      expect(DefaultProfiles.getProfileForFile('test.tsx').name,
          'JavaScript/TypeScript');
      expect(DefaultProfiles.getProfileForFile('test.java').name, 'Java/C#');
      expect(DefaultProfiles.getProfileForFile('test.cs').name, 'Java/C#');
      expect(DefaultProfiles.getProfileForFile('test.go').name, 'Go');
      expect(DefaultProfiles.getProfileForFile('test.txt').name,
          'Generic/C-Family');
    });
  });
}
