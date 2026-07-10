import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

/// SourceFileFilter scopes hotspot interpretation to source code
/// (Tornhill 2015). These tests pin the denylist orientation: definite
/// non-code (prose, config, locks, media) is rejected, everything
/// unknown — including languages the codebase has no profile for —
/// passes, so no repository's real hotspots are silently dropped.
void main() {
  test('rejects prose and documentation', () {
    expect(SourceFileFilter.isSource('CHANGELOG.md'), isFalse);
    expect(SourceFileFilter.isSource('doc/guide/README.md'), isFalse);
    expect(SourceFileFilter.isSource('docs/index.rst'), isFalse);
    expect(SourceFileFilter.isSource('notes.txt'), isFalse);
  });

  test('rejects data, config, and lockfiles', () {
    expect(SourceFileFilter.isSource('package.json'), isFalse);
    expect(SourceFileFilter.isSource('config/app.yaml'), isFalse);
    expect(SourceFileFilter.isSource('pubspec.lock'), isFalse);
    expect(SourceFileFilter.isSource('go.sum'), isFalse);
    expect(SourceFileFilter.isSource('settings.toml'), isFalse);
    expect(SourceFileFilter.isSource('data/export.csv'), isFalse);
  });

  test('rejects media and binaries', () {
    expect(SourceFileFilter.isSource('assets/logo.svg'), isFalse);
    expect(SourceFileFilter.isSource('img/shot.PNG'), isFalse);
    expect(SourceFileFilter.isSource('dist/app.jar'), isFalse);
  });

  test('rejects extensionless repo prose and VCS config by basename', () {
    expect(SourceFileFilter.isSource('LICENSE'), isFalse);
    expect(SourceFileFilter.isSource('.gitignore'), isFalse);
    expect(SourceFileFilter.isSource('AUTHORS'), isFalse);
    expect(SourceFileFilter.isSource('sub/dir/CODEOWNERS'), isFalse);
  });

  test('accepts known source languages', () {
    expect(SourceFileFilter.isSource('lib/src/main.dart'), isTrue);
    expect(SourceFileFilter.isSource('app/models/user.rb'), isTrue);
    expect(SourceFileFilter.isSource('src/lib.rs'), isTrue);
    expect(SourceFileFilter.isSource('kernel/sched.c'), isTrue);
  });

  test('accepts unknown extensions and extensionless build files', () {
    expect(SourceFileFilter.isSource('src/parser.weird'), isTrue);
    expect(SourceFileFilter.isSource('Makefile'), isTrue);
    expect(SourceFileFilter.isSource('Dockerfile'), isTrue);
  });

  test('basename denylist does not swallow real code files', () {
    expect(SourceFileFilter.isSource('lib/version.dart'), isTrue);
    expect(SourceFileFilter.isSource('lib/changelog_generator.dart'), isTrue);
  });

  test('rejects IDE metadata and compiled objects for core languages', () {
    // C# ecosystem
    expect(SourceFileFilter.isSource('App.csproj'), isFalse);
    expect(SourceFileFilter.isSource('solution.sln'), isFalse);
    // Java ecosystem
    expect(SourceFileFilter.isSource('module.iml'), isFalse);
    expect(SourceFileFilter.isSource('.classpath'), isFalse);
    expect(SourceFileFilter.isSource('Main.class'), isFalse);
    // C/C++ ecosystem
    expect(SourceFileFilter.isSource('project.vcxproj'), isFalse);
    expect(SourceFileFilter.isSource('build/main.o'), isFalse);
    // JS/TS and Dart ecosystem
    expect(SourceFileFilter.isSource('main.js.map'), isFalse);
    expect(SourceFileFilter.isSource('.packages'), isFalse);
  });

  test('normalises diff-style and windows paths', () {
    expect(SourceFileFilter.isSource(r'doc\notes\INDEX.md'), isFalse);
    expect(SourceFileFilter.isSource(' CHANGELOG.md '), isFalse);
  });
}
