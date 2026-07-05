import '../../constants.dart';
import '../../models/architecture_drift_dto.dart';
import '../../vcs/git_query.dart';

/// ----------------------------------------------------------------------------
/// architecture_drift_algorithm.dart
/// ----------------------------------------------------------------------------
/// Detects architectural drift from commit history: commits that modify
/// multiple independent architectural layers simultaneously indicate tight
/// coupling or leaky abstractions (Perry & Wolf 1992). From the drift
/// commits it derives a layer-pair coupling matrix, entanglement ratios,
/// and the architectural bad smells catalogued by Garcia, Oliveira & Murta
/// (2009): God Component, Hub-Like Dependency, and Scattered Functionality.
///
/// Shared, library-first (ADR-0005), by the `analyze_architecture_drift`
/// MCP tool (caller-supplied layer regexes) and the report meta-tools
/// (layers inferred from repository structure via [inferLayerPatterns]).
class ArchitectureDriftAlgorithm {
  final GitQuery gitQuery;

  ArchitectureDriftAlgorithm(this.gitQuery);

  /// Analyzes the history window ([since] date filter and/or [limit] commit
  /// cap) of [directory], assigning each changed file to the first matching
  /// layer in [layerRegexes] and flagging commits spanning >1 layer.
  Future<ArchitectureDriftDto> execute(
    String directory,
    Map<String, RegExp> layerRegexes, {
    String? since,
    String? limit,
  }) async {
    final logResult = await gitQuery.run(directory, [
      'log',
      if (since != null) '--since=$since',
      if (limit != null) '-n',
      if (limit != null) limit,
      '--format=%H||%s',
      '--name-only',
    ]);
    final out = logResult.getOrThrow().trim();
    if (out.isEmpty) return const ArchitectureDriftDto.empty();

    final commitLayers = <String, Set<String>>{};
    final commitMessages = <String, String>{};
    String currentCommit = '';
    for (final line in out.split('\n')) {
      if (line.isEmpty) continue;
      if (line.contains('||')) {
        final parts = line.split('||');
        currentCommit = parts[0];
        commitLayers[currentCommit] = {};
        commitMessages[currentCommit] = parts.sublist(1).join('||');
        continue;
      }
      if (currentCommit.isNotEmpty) {
        for (final entry in layerRegexes.entries) {
          if (entry.value.hasMatch(line)) {
            commitLayers[currentCommit]!.add(entry.key);
          }
        }
      }
    }

    final driftCommits = <DriftCommit>[];
    final couplingMatrix = <String, Map<String, int>>{};
    for (final entry in commitLayers.entries) {
      final layers = entry.value.toList()..sort();
      if (layers.length <= 1) continue;
      driftCommits.add(DriftCommit(
        hash: entry.key,
        message: commitMessages[entry.key] ?? '',
        layersCoupled: layers,
      ));
      for (int i = 0; i < layers.length; i++) {
        for (int j = i + 1; j < layers.length; j++) {
          couplingMatrix.putIfAbsent(layers[i], () => {});
          couplingMatrix[layers[i]]![layers[j]] =
              (couplingMatrix[layers[i]]![layers[j]] ?? 0) + 1;
          couplingMatrix.putIfAbsent(layers[j], () => {});
          couplingMatrix[layers[j]]![layers[i]] =
              (couplingMatrix[layers[j]]![layers[i]] ?? 0) + 1;
        }
      }
    }

    final totalAnalyzed = commitLayers.length;
    final numLayers = layerRegexes.length;
    final maxPairs = numLayers > 1 ? numLayers * (numLayers - 1) ~/ 2 : 0;
    int coupledPairCount = 0;
    for (final row in couplingMatrix.values) {
      coupledPairCount += row.length;
    }
    // The matrix is symmetric, so each coupled pair was counted twice.
    coupledPairCount ~/= 2;

    return ArchitectureDriftDto(
      totalCommitsAnalyzed: totalAnalyzed,
      driftCommits: driftCommits,
      couplingMatrix: couplingMatrix,
      couplingRatio:
          totalAnalyzed > 0 ? driftCommits.length / totalAnalyzed : 0.0,
      couplingDensity: maxPairs > 0 ? coupledPairCount / maxPairs : 0.0,
      smells: _detectSmells(driftCommits, couplingMatrix, numLayers),
    );
  }

  List<ArchitecturalSmell> _detectSmells(
    List<DriftCommit> driftCommits,
    Map<String, Map<String, int>> couplingMatrix,
    int numLayers,
  ) {
    if (driftCommits.isEmpty) return const [];
    final smells = <ArchitecturalSmell>[];

    // God Component: a layer involved in more than half of drift commits
    // has accumulated too many cross-cutting concerns.
    final layerDriftCount = <String, int>{};
    for (final commit in driftCommits) {
      for (final layer in commit.layersCoupled) {
        layerDriftCount[layer] = (layerDriftCount[layer] ?? 0) + 1;
      }
    }
    for (final entry in layerDriftCount.entries) {
      if (entry.value > driftCommits.length * godComponentDriftShareThreshold) {
        smells.add(ArchitecturalSmell(
          type: 'God Component',
          layer: entry.key,
          description:
              'Layer "${entry.key}" appears in ${entry.value}/${driftCommits.length} '
              'drift commits. It has too many cross-cutting concerns and likely '
              'violates the Single Responsibility Principle at the architecture level.',
        ));
      }
    }

    // Hub-Like Dependency: a layer coupled with at least half of all other
    // layers acts as a central coupling hub.
    if (numLayers >= hubLikeDependencyMinimumLayers) {
      for (final entry in couplingMatrix.entries) {
        final degree = entry.value.length;
        if (degree >= numLayers / 2) {
          smells.add(ArchitecturalSmell(
            type: 'Hub-Like Dependency',
            layer: entry.key,
            description:
                'Layer "${entry.key}" is coupled with $degree/${numLayers - 1} '
                'other layers, acting as a central coupling hub and introducing '
                'fragility.',
          ));
        }
      }
    }

    // Scattered Functionality: single commits spanning three or more layers
    // suggest concerns not cleanly assigned to any one layer.
    final scattered = driftCommits
        .where((commit) =>
            commit.layersCoupled.length >= scatteredFunctionalityLayerCount)
        .length;
    if (scattered > 0) {
      smells.add(ArchitecturalSmell(
        type: 'Scattered Functionality',
        count: scattered,
        description:
            '$scattered commits simultaneously modify 3 or more layers, '
            'suggesting business logic or infrastructure concerns that are not '
            'cleanly assigned to a single layer.',
      ));
    }

    return smells;
  }

  /// Infers architectural layers from repository file paths for report-grade
  /// analysis, where no caller-supplied layer map exists. Each file's layer
  /// is its first meaningful directory: generic source containers (`lib`,
  /// `src`, ...) are descended into, and non-architecture directories
  /// (tests, docs, build output) are excluded so expected co-change (code +
  /// its test) does not read as drift. Layers are ranked by file count and
  /// capped at [maxInferredArchitectureLayers]; fewer than
  /// [minInferredArchitectureLayers] distinct layers yields an empty map
  /// (no boundaries to violate).
  static Map<String, RegExp> inferLayerPatterns(Iterable<String> filePaths) {
    const genericContainers = {'lib', 'src', 'app', 'packages', 'pkg'};
    const excludedDirectories = {
      'test',
      'tests',
      'doc',
      'docs',
      'example',
      'examples',
      'build',
      'dist',
      'coverage',
      'node_modules',
      'vendor',
      'third_party',
    };

    final fileCountByLayerPrefix = <String, int>{};
    for (final path in filePaths) {
      final segments = path.split('/');
      // The last segment is the file name; layers are directories.
      if (segments.length < 2) continue;
      if (segments.first.startsWith('.')) continue;
      if (excludedDirectories.contains(segments.first)) continue;

      var layerDepth = 0;
      while (layerDepth < segments.length - 1 &&
          genericContainers.contains(segments[layerDepth])) {
        layerDepth++;
      }
      // A file sitting directly inside a generic container has no layer.
      if (layerDepth >= segments.length - 1 && layerDepth > 0) continue;
      final prefix = segments.sublist(0, layerDepth + 1).join('/');
      fileCountByLayerPrefix[prefix] =
          (fileCountByLayerPrefix[prefix] ?? 0) + 1;
    }

    final rankedPrefixes = fileCountByLayerPrefix.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topPrefixes =
        rankedPrefixes.take(maxInferredArchitectureLayers).toList();
    if (topPrefixes.length < minInferredArchitectureLayers) return const {};

    // The full prefix path is the layer name: unambiguous when two branches
    // share a leaf directory name (e.g. `lib/src/core` vs `tool/core`).
    return {
      for (final entry in topPrefixes)
        entry.key: RegExp('^${RegExp.escape(entry.key)}/'),
    };
  }
}
