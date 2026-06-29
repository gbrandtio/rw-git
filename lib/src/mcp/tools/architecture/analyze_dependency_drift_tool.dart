import 'dart:convert';
import '../../../../rw_git.dart';
import '../../utils/mcp_argument_extensions.dart';

/// analyze_dependency_drift_tool.dart
/// Analyzes dependency manifests for version pinning
/// and supply chain risk.

class AnalyzeDependencyDriftTool implements McpTool {
  final CodeQualityTracker tracker;

  AnalyzeDependencyDriftTool(this.tracker);

  @override
  String get name => 'analyze_dependency_drift';

  @override
  String get description => 'Parses dependency manifests (pubspec.yaml, '
      'package.json, requirements.txt, go.mod, '
      'Cargo.toml, Gemfile) from the git working tree. '
      'Returns a structured report of pinned vs '
      'floating dependencies and lock file presence '
      'for each ecosystem. '
      'For a complete guide, invoke the '
      'get_rw_git_documentation tool.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'directory': {
            'type': 'string',
            'description': 'The local repository path.',
          },
        },
        'required': ['directory'],
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments.getStringArgument('directory');

    final manifests = await tracker.parseDependencyManifests(directory);

    final ecosystems = manifests.ecosystems
        .map((e) => {
              'type': e.type,
              'manifest_file': e.manifestFile,
              'total_dependencies': e.totalDependencies,
              'pinned_count': e.pinnedCount,
              'floating_count': e.floatingCount,
              'has_lock_file': e.hasLockFile,
            })
        .toList();

    // Compute overall risk
    int totalDeps = 0;
    int totalFloating = 0;
    int missingLocks = 0;
    for (final eco in manifests.ecosystems) {
      totalDeps += eco.totalDependencies;
      totalFloating += eco.floatingCount;
      if (!eco.hasLockFile) {
        missingLocks++;
      }
    }

    String overallRisk;
    if (totalDeps == 0) {
      overallRisk = 'none';
    } else if (totalFloating == 0 && missingLocks == 0) {
      overallRisk = 'low';
    } else if (totalFloating / totalDeps > 0.5 || missingLocks > 0) {
      overallRisk = 'high';
    } else {
      overallRisk = 'medium';
    }

    return jsonEncode({
      'ecosystems': ecosystems,
      'total_dependencies': totalDeps,
      'total_floating': totalFloating,
      'missing_lock_files': missingLocks,
      'overall_risk': overallRisk,
    });
  }
}
