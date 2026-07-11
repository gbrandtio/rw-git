import 'dart:convert';
import '../../../../rw_git.dart';
import '../../utils/mcp_argument_extensions.dart';

/// analyze_dependency_drift_tool.dart
/// Analyzes dependency manifests for version pinning
/// and supply chain risk.

class AnalyzeDependencyDriftTool implements McpTool {
  final ProcessRunner runner;
  final RwHttpClient httpClient;

  AnalyzeDependencyDriftTool(this.runner, {RwHttpClient? httpClient})
      : httpClient = httpClient ??
            RwHttpClient.defaultClient(interceptors: [RetryInterceptor()]);

  @override
  String get name => 'analyze_dependency_drift';

  @override
  String get description => 'Parses dependency manifests (pubspec.yaml, '
      'package.json, requirements.txt, go.mod, '
      'Cargo.toml, Gemfile) from the git working tree. '
      'Returns a structured report of pinned vs '
      'floating dependencies and lock file presence '
      'for each ecosystem. Optionally (check_freshness=true) '
      'performs network lookups against each ecosystem\'s '
      'package registry to compare declared versions against '
      'the latest available release. '
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
          'check_freshness': {
            'type': 'boolean',
            'description': 'Optional. When true, performs network lookups '
                'against each ecosystem\'s package registry (pub.dev, '
                'npmjs.org, pypi.org, crates.io, proxy.golang.org, '
                'rubygems.org) to compare declared versions against the '
                'latest available, and adds a "freshness" block per '
                'dependency. Default false (fully offline).',
          },
        },
        'required': ['directory'],
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments.getStringArgument('directory');
    final checkFreshness =
        arguments.getOptionalBoolArgument('check_freshness') ?? false;

    final manifests = await DependencyManifestParser(
      runner,
    ).parseDependencyManifests(directory);

    final freshnessChecker =
        checkFreshness ? DependencyFreshnessChecker(httpClient) : null;

    final freshnessCounts = <String, int>{
      'current': 0,
      'patch_behind': 0,
      'minor_behind': 0,
      'major_behind': 0,
      'unknown': 0,
    };

    final ecosystems = <Map<String, dynamic>>[];
    for (final e in manifests.ecosystems) {
      final ecoJson = <String, dynamic>{
        'type': e.type,
        'manifest_file': e.manifestFile,
        'total_dependencies': e.totalDependencies,
        'pinned_count': e.pinnedCount,
        'floating_count': e.floatingCount,
        'has_lock_file': e.hasLockFile,
      };

      if (checkFreshness) {
        final freshnessResults = await freshnessChecker!.checkFreshness(
          e.dependencies,
          e.type,
        );
        final freshnessByName = {for (final r in freshnessResults) r.name: r};

        ecoJson['dependencies'] = e.dependencies.map((dep) {
          final freshness = freshnessByName[dep.name];
          if (freshness != null) {
            freshnessCounts[freshness.classification] =
                (freshnessCounts[freshness.classification] ?? 0) + 1;
          }
          return {
            'name': dep.name,
            'declared_version': dep.declaredVersion,
            'is_pinned': dep.isPinned,
            'freshness': {
              'latest_version': freshness?.latestVersion,
              'classification': freshness?.classification ?? 'unknown',
              'error': freshness?.error,
            },
          };
        }).toList();
      }

      ecosystems.add(ecoJson);
    }

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

    final result = <String, dynamic>{
      'ecosystems': ecosystems,
      'total_dependencies': totalDeps,
      'total_floating': totalFloating,
      'missing_lock_files': missingLocks,
      'overall_risk': overallRisk,
    };

    if (checkFreshness) {
      result['freshness_summary'] = {'checked': true, ...freshnessCounts};
    }

    return jsonEncode(result);
  }
}
