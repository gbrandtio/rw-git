import 'dart:io';
import 'package:test/test.dart';
import 'package:rw_git/rw_git.dart';

void main() {
  late StandardProcessRunner runner;
  late DependencyManifestParser parser;
  late Directory tempDir;
  late RwGit rwGit;

  setUp(() async {
    runner = StandardProcessRunner();
    parser = DependencyManifestParser(runner);
    rwGit = RwGit();
    tempDir = await Directory.systemTemp.createTemp('manifest_test');

    await rwGit.init(tempDir.path);

    await runner.run(
        'git',
        [
          'config',
          'user.name',
          'Test User',
        ],
        workingDirectory: tempDir.path);
    await runner.run(
        'git',
        [
          'config',
          'user.email',
          'test@example.com',
        ],
        workingDirectory: tempDir.path);

    final pkgJson = File('${tempDir.path}/package.json');
    await pkgJson.writeAsString(
      '{\n"dependencies": {\n"lodash": "^4.17.21"\n},\n"devDependencies": {\n"jest": "27.0.0"\n}\n}',
    );

    // Create a pubspec.yaml
    final pubspec = File('${tempDir.path}/pubspec.yaml');
    await pubspec.writeAsString(
      'dependencies:\n  http: ^0.13.3\ndev_dependencies:\n  test: 1.16.0',
    );

    // Create requirements.txt
    final reqs = File('${tempDir.path}/requirements.txt');
    await reqs.writeAsString('requests==2.26.0\nnumpy>=1.21.2');

    // Create go.mod
    final goMod = File('${tempDir.path}/go.mod');
    await goMod.writeAsString(
      'module example\ngo 1.16\nrequire (\n\tgithub.com/gin-gonic/gin v1.7.4\n)',
    );

    // Create Cargo.toml
    final cargo = File('${tempDir.path}/Cargo.toml');
    await cargo.writeAsString(
      '[dependencies]\nserde = "1.0"\nserde_json = "=1.0.64"',
    );

    // Create Gemfile
    final gemfile = File('${tempDir.path}/Gemfile');
    await gemfile.writeAsString(
      "source 'https://rubygems.org'\ngem 'rails', '~> 6.1.4'\ngem 'sqlite3', '1.4.2'",
    );

    // Add lockfiles
    final pubspecLock = File('${tempDir.path}/pubspec.lock');
    await pubspecLock.writeAsString('lock');
    final packageLock = File('${tempDir.path}/package-lock.json');
    await packageLock.writeAsString('lock');

    await runner.run('git', ['add', '.'], workingDirectory: tempDir.path);
    await runner.run(
        'git',
        [
          'commit',
          '-m',
          'Initial',
        ],
        workingDirectory: tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('DependencyManifestParser', () {
    test('parses dependency manifests correctly', () async {
      final result = await parser.parseDependencyManifests(tempDir.path);

      expect(result.ecosystems.length, 6);

      final npm = result.ecosystems.firstWhere((e) => e.type == 'npm');
      expect(npm.totalDependencies, 2);
      expect(npm.pinnedCount, 1);
      expect(npm.floatingCount, 1);
      expect(npm.hasLockFile, isTrue);
      expect(
        npm.dependencies,
        containsAll([
          isA<DependencyEntry>()
              .having((e) => e.name, 'name', 'lodash')
              .having((e) => e.declaredVersion, 'declaredVersion', '^4.17.21')
              .having((e) => e.isPinned, 'isPinned', isFalse),
          isA<DependencyEntry>()
              .having((e) => e.name, 'name', 'jest')
              .having((e) => e.declaredVersion, 'declaredVersion', '27.0.0')
              .having((e) => e.isPinned, 'isPinned', isTrue),
        ]),
      );

      final dart = result.ecosystems.firstWhere((e) => e.type == 'dart');
      expect(dart.totalDependencies, 2);
      expect(dart.pinnedCount, 1);
      expect(dart.floatingCount, 1);
      expect(dart.hasLockFile, isTrue);
      expect(
        dart.dependencies,
        containsAll([
          isA<DependencyEntry>()
              .having((e) => e.name, 'name', 'http')
              .having((e) => e.isPinned, 'isPinned', isFalse),
          isA<DependencyEntry>()
              .having((e) => e.name, 'name', 'test')
              .having((e) => e.isPinned, 'isPinned', isTrue),
        ]),
      );

      final python = result.ecosystems.firstWhere((e) => e.type == 'python');
      expect(python.totalDependencies, 2);
      expect(python.pinnedCount, 1);
      expect(python.floatingCount, 1);
      expect(python.hasLockFile, isTrue);
      expect(
        python.dependencies,
        containsAll([
          isA<DependencyEntry>()
              .having((e) => e.name, 'name', 'requests')
              .having((e) => e.isPinned, 'isPinned', isTrue),
          isA<DependencyEntry>()
              .having((e) => e.name, 'name', 'numpy')
              .having((e) => e.isPinned, 'isPinned', isFalse),
        ]),
      );

      final go = result.ecosystems.firstWhere((e) => e.type == 'go');
      expect(go.totalDependencies, 1);
      expect(go.pinnedCount, 1);
      expect(go.floatingCount, 0);
      expect(go.dependencies.first.name, 'github.com/gin-gonic/gin');

      final rust = result.ecosystems.firstWhere((e) => e.type == 'rust');
      expect(rust.totalDependencies, 2);
      expect(rust.pinnedCount, 1);
      expect(rust.floatingCount, 1);
      expect(
        rust.dependencies,
        containsAll([
          isA<DependencyEntry>()
              .having((e) => e.name, 'name', 'serde')
              .having((e) => e.isPinned, 'isPinned', isFalse),
          isA<DependencyEntry>()
              .having((e) => e.name, 'name', 'serde_json')
              .having((e) => e.isPinned, 'isPinned', isTrue),
        ]),
      );

      final ruby = result.ecosystems.firstWhere((e) => e.type == 'ruby');
      expect(ruby.totalDependencies, 2);
      expect(ruby.pinnedCount, 1);
      expect(ruby.floatingCount, 1);
      expect(
        ruby.dependencies,
        containsAll([
          isA<DependencyEntry>()
              .having((e) => e.name, 'name', 'rails')
              .having((e) => e.isPinned, 'isPinned', isFalse),
          isA<DependencyEntry>()
              .having((e) => e.name, 'name', 'sqlite3')
              .having((e) => e.isPinned, 'isPinned', isTrue),
        ]),
      );
    });
  });
}
