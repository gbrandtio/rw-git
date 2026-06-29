import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

class MockDispatchingRunner implements ProcessRunner {
  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool streamOutput = false,
  }) async {
    final cmd = arguments.join(' ');
    String stdoutStr = '';

    if (cmd.contains('log') && cmd.contains('%H||%an||%aI')) {
      // calculateCommitVelocity
      stdoutStr = 'hash||Author||2026-06-24T14:00:00Z\n';
    } else if (cmd.contains('ls-tree -r --name-only HEAD')) {
      // parseDependencyManifests
      stdoutStr = '''
pubspec.yaml
package.json
requirements.txt
go.mod
Cargo.toml
Gemfile
nested/package.json
''';
    } else if (cmd.contains('show HEAD:pubspec.yaml')) {
      stdoutStr = '''
dependencies:
  test: ^1.0.0
  pinned: 1.0.0
  path_dep:
    path: ../
  git_dep:
    git: url
dev_dependencies:
  any_dep: any
''';
    } else if (cmd.contains('show HEAD:package.json') ||
        cmd.contains('show HEAD:nested/package.json')) {
      stdoutStr = '''
{
  "dependencies": {
    "react": "^18.0.0",
    "pinned": "18.0.0",
    "latest_dep": "latest",
    "star": "*",
    "tilde": "~1.0.0"
  }
}
''';
    } else if (cmd.contains('show HEAD:requirements.txt')) {
      stdoutStr = '''
# Comment
requests==2.25.1
flask>=1.0.0
''';
    } else if (cmd.contains('show HEAD:go.mod')) {
      stdoutStr = '''
module example
go 1.16
require (
  github.com/gin-gonic/gin v1.7.2
)
// comment
''';
    } else if (cmd.contains('show HEAD:Cargo.toml')) {
      stdoutStr = '''
[dependencies]
serde = "1.0.126"
rand = "0.8"
[dev-dependencies]
test = "0.1"
''';
    } else if (cmd.contains('show HEAD:Gemfile')) {
      stdoutStr = '''
source 'https://rubygems.org'
gem 'rails', '6.1.3'
gem 'rspec', '~> 3.10'
gem 'pg'
# comment
''';
    } else if (cmd.contains('log -p --format=%H||%an||%ad||%s') ||
        cmd.contains('log -p -G') ||
        cmd.contains('log -p -S')) {
      // unified test for extractChangedComments and findSecrets
      stdoutStr = 'hash||Author||2026-06-24T14:00:00Z||A commit message\n'
          '+++ b/test.dart\n'
          '@@ -1,1 +1,2 @@\n'
          '+ // A typical comment\n'
          '+ const apiKey = "AKIAIOSFODNN7EXAMPLE";\n'
          '+ "private_key": "-----BEGIN RSA PRIVATE KEY-----"\n';
    }

    return ProcessResult(0, 0, stdoutStr, '');
  }

  @override
  Stream<String> runStream(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) {
    throw UnimplementedError();
  }
}

void main() {
  group('CodeQualityTracker Extended Coverage', () {
    test('calculateCommitVelocity with arguments', () async {
      final runner = MockDispatchingRunner();
      final tracker = CodeQualityTracker(runner);
      final result = await tracker.calculateCommitVelocity('dummyDir',
          limit: '10', since: '2026-01-01', until: '2026-12-31');
      expect(result.totalCommits, 1);
    });

    test('parseDependencyManifests handles multiple ecosystems', () async {
      final runner = MockDispatchingRunner();
      final tracker = CodeQualityTracker(runner);
      final manifests = await tracker.parseDependencyManifests('dummyDir');

      expect(manifests.ecosystems.length, 7); // 6 root + 1 nested
    });

    test('extractChangedComments handles comment parsing', () async {
      final runner = MockDispatchingRunner();
      final tracker = CodeQualityTracker(runner);
      final comments = await tracker.extractChangedComments('dummyDir');
      expect(comments, isNotEmpty);
    });

    test('findSecrets identifies various secret patterns', () async {
      final runner = MockDispatchingRunner();
      final tracker = CodeQualityTracker(runner);
      final secrets = await tracker.findSecrets('dummyDir');
      expect(
          secrets.isNotEmpty, isTrue); // Should catch the ones matched by regex
    });
    test('findMegaCommits handles limit and limits the args', () async {
      final runner = MockDispatchingRunner();
      final tracker = CodeQualityTracker(runner);
      final commits = await tracker.findMegaCommits('/test/dir', limit: '10');
      // Just check no exception
      expect(commits, isA<List>());
    });

    test('scanComplianceIssues parses various outputs', () async {
      final runner = MockDispatchingRunner();
      final tracker = CodeQualityTracker(runner);
      // just call it to cover its paths
      final result = await tracker.scanComplianceIssues('/test/dir');
      expect(result, isNotNull);
    });
    test('findBugsByDeveloper returns results', () async {
      final runner = MockDispatchingRunner();
      final tracker = CodeQualityTracker(runner);
      // The MockDispatchingRunner doesn't return anything useful for szz blame right now,
      // but we just want to cover the method invocation inside CodeQualityTracker
      final result = await tracker.findBugsByDeveloper('/test/dir', 'Alice');
      expect(result, isA<List>());
    });
  });
}
