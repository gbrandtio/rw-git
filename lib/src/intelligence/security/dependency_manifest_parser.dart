import 'dart:isolate';
import 'package:rw_git/src/core/process_runner.dart';
import 'package:rw_git/src/models/dependency_manifest_dto.dart';

/// ----------------------------------------------------------------------------
/// dependency_manifest_parser.dart
/// ----------------------------------------------------------------------------
class DependencyManifestParser {
  final ProcessRunner runner;

  DependencyManifestParser(this.runner);

  /// Reads dependency manifests from the git working tree
  /// and parses them for pinned/floating analysis.
  Future<DependencyManifestDto> parseDependencyManifests(
      String directory) async {
    // Check which manifest files exist in HEAD
    final lsResult = await runner.run(
      'git',
      ['ls-tree', '-r', '--name-only', 'HEAD'],
      workingDirectory: directory,
    );
    evaluateProcessResult(lsResult);
    final allFiles = (lsResult.stdout?.toString() ?? '')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    final manifestMap = <String, String>{
      'pubspec.yaml': 'dart',
      'package.json': 'npm',
      'requirements.txt': 'python',
      'go.mod': 'go',
      'Cargo.toml': 'rust',
      'Gemfile': 'ruby',
    };

    final lockFileMap = <String, String>{
      'dart': 'pubspec.lock',
      'npm': 'package-lock.json',
      'python': 'requirements.txt',
      'go': 'go.sum',
      'rust': 'Cargo.lock',
      'ruby': 'Gemfile.lock',
    };

    final ecosystems = <EcosystemReport>[];

    for (final entry in manifestMap.entries) {
      // Find manifests at any path depth
      final matches = allFiles
          .where(
            (f) => f == entry.key || f.endsWith('/${entry.key}'),
          )
          .toList();

      for (final manifestPath in matches) {
        // Read manifest content via git show
        final showResult = await runner.run(
          'git',
          ['show', 'HEAD:$manifestPath'],
          workingDirectory: directory,
        );
        evaluateProcessResult(showResult);
        final content = showResult.stdout?.toString() ?? '';

        // Check for corresponding lock file
        final lockFileName = lockFileMap[entry.value] ?? '';
        final dir = manifestPath.contains('/')
            ? manifestPath.substring(0, manifestPath.lastIndexOf('/') + 1)
            : '';
        final hasLock = allFiles.contains('$dir$lockFileName');

        final report = await Isolate.run(
          () => _parseSingleManifest(
            content,
            entry.value,
            manifestPath,
            hasLock,
          ),
        );
        ecosystems.add(report);
      }
    }

    return DependencyManifestDto(ecosystems: ecosystems);
  }
}

EcosystemReport _parseSingleManifest(
  String content,
  String ecosystemType,
  String manifestPath,
  bool hasLock,
) {
  int pinned = 0;
  int floating = 0;

  switch (ecosystemType) {
    case 'dart':
      // Parse pubspec.yaml dependencies
      final depRegex = RegExp(
        r'^\s+\w[\w_]*:\s*(.+)$',
        multiLine: true,
      );
      bool inDeps = false;
      for (final line in content.split('\n')) {
        if (line.startsWith('dependencies:') ||
            line.startsWith('dev_dependencies:')) {
          inDeps = true;
          continue;
        }
        if (inDeps &&
            line.isNotEmpty &&
            !line.startsWith(' ') &&
            !line.startsWith('\t')) {
          inDeps = false;
          continue;
        }
        if (inDeps) {
          final match = depRegex.firstMatch(line);
          if (match != null) {
            final version = match.group(1)?.trim() ?? '';
            if (_isPinnedVersion(version)) {
              pinned++;
            } else {
              floating++;
            }
          }
        }
      }

    case 'npm':
      // Parse package.json dependencies
      final depRegex = RegExp(
        r'"[^"]+"\s*:\s*"([^"]+)"',
      );
      bool inDeps = false;
      int braceDepth = 0;
      for (final line in content.split('\n')) {
        if (line.contains('"dependencies"') ||
            line.contains('"devDependencies"')) {
          inDeps = true;
          braceDepth = 0;
          continue;
        }
        if (inDeps) {
          braceDepth +=
              '{'.allMatches(line).length - '}'.allMatches(line).length;
          if (braceDepth < 0) {
            inDeps = false;
            continue;
          }
          final match = depRegex.firstMatch(line);
          if (match != null) {
            final version = match.group(1) ?? '';
            if (_isNpmPinned(version)) {
              pinned++;
            } else {
              floating++;
            }
          }
        }
      }

    case 'python':
      // Parse requirements.txt
      for (final line in content.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) {
          continue;
        }
        if (trimmed.contains('==')) {
          pinned++;
        } else {
          floating++;
        }
      }

    case 'go':
      // Parse go.mod require block
      for (final line in content.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.startsWith('require') ||
            trimmed.startsWith(')') ||
            trimmed.startsWith('(') ||
            trimmed.isEmpty ||
            trimmed.startsWith('module') ||
            trimmed.startsWith('go ') ||
            trimmed.startsWith('//')) {
          continue;
        }
        // Go modules are always pinned
        pinned++;
      }

    case 'rust':
      // Parse Cargo.toml [dependencies]
      bool inDeps = false;
      for (final line in content.split('\n')) {
        final trimmed = line.trim();
        if (trimmed == '[dependencies]' || trimmed == '[dev-dependencies]') {
          inDeps = true;
          continue;
        }
        if (trimmed.startsWith('[') && inDeps) {
          inDeps = false;
          continue;
        }
        if (inDeps && trimmed.contains('=')) {
          if (trimmed.contains('"=') ||
              RegExp(r'"\d+\.\d+\.\d+"').hasMatch(trimmed)) {
            pinned++;
          } else {
            floating++;
          }
        }
      }

    case 'ruby':
      // Parse Gemfile
      final gemRegex = RegExp(r"gem\s+'[^']+'");
      for (final line in content.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty ||
            trimmed.startsWith('#') ||
            trimmed.startsWith('source') ||
            trimmed.startsWith('group')) {
          continue;
        }
        if (gemRegex.hasMatch(trimmed)) {
          // Check if version is specified
          final parts = trimmed.split(',');
          if (parts.length > 1) {
            final versionPart = parts[1].trim();
            if (versionPart.startsWith("'~>")) {
              floating++;
            } else {
              pinned++;
            }
          } else {
            floating++; // No version = floating
          }
        }
      }
  }

  return EcosystemReport(
    type: ecosystemType,
    manifestFile: manifestPath,
    totalDependencies: pinned + floating,
    pinnedCount: pinned,
    floatingCount: floating,
    hasLockFile: hasLock,
  );
}

bool _isPinnedVersion(String version) {
  // Exact version like 1.0.0 or hosted with version
  if (version.isEmpty) return false;
  // Caret/range specifiers are floating
  if (version.startsWith('^') || version.startsWith('>')) {
    return false;
  }
  // "any" is floating
  if (version == 'any') return false;
  // Path or git dependencies are considered pinned
  if (version.startsWith('path:') || version.startsWith('git:')) {
    return true;
  }
  // Exact semver
  return RegExp(r'^\d+\.\d+\.\d+').hasMatch(version);
}

bool _isNpmPinned(String version) {
  if (version.startsWith('^') ||
      version.startsWith('~') ||
      version.startsWith('>') ||
      version == '*' ||
      version == 'latest') {
    return false;
  }
  return true;
}
