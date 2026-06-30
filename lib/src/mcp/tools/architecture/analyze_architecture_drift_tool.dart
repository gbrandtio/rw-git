import 'dart:convert';
import '../../../../rw_git.dart';
import '../../utils/mcp_argument_extensions.dart';

/// analyze_architecture_drift_tool.dart
/// Analyzes git history to detect architectural drift and tight coupling
/// between defined logical layers.

class AnalyzeArchitectureDriftTool implements McpTool {
  final RwGit rwGit;

  AnalyzeArchitectureDriftTool(this.rwGit);

  @override
  String get name => 'analyze_architecture_drift';

  @override
  String get description => 'Analyzes git history to detect architectural '
      'drift by identifying commits that modify multiple '
      'independent architectural layers simultaneously, '
      'indicating tight coupling or leaky abstractions. '
      'Returns a list of violating commits and a coupling matrix.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'directory': {
            'type': 'string',
            'description': 'The local repository path.',
          },
          'layer_patterns': {
            'type': 'object',
            'description': 'A map where keys are layer names (e.g., "ui", "data") '
                'and values are regex strings matching file paths for that layer.',
          },
          'since': {
            'type': 'string',
            'description': 'Date string (e.g. "90 days ago").',
          }
        },
        'required': ['directory', 'layer_patterns'],
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments.getStringArgument('directory');
    final layerPatternsMap =
        arguments['layer_patterns'] as Map<String, dynamic>;
    final since = arguments.getOptionalStringArgument('since') ?? '90 days ago';

    final layerRegexes = <String, RegExp>{};
    for (final entry in layerPatternsMap.entries) {
      try {
        layerRegexes[entry.key] = RegExp(entry.value.toString());
      } on FormatException catch (e) {
        return jsonEncode({
          'error': 'Invalid regex pattern for layer "${entry.key}": '
              '${e.message}',
        });
      }
    }

    final logRes = await rwGit.runCommand(
      directory,
      ['log', '--since=$since', '--format=%H||%s', '--name-only'],
    );
    if (logRes.isFailure) {
      return jsonEncode({'error': 'Git log failed: \${logRes.getOrNull()}'});
    }

    final out = logRes.getOrThrow().trim();
    if (out.isEmpty) return jsonEncode({'risk': 'none'});

    final lines = out.split('\n');
    String currentCommit = '';
    String currentMsg = '';

    // Commit -> Set of layers modified
    final commitLayers = <String, Set<String>>{};
    final commitMessages = <String, String>{};
    final couplingMatrix = <String, Map<String, int>>{};

    for (final line in lines) {
      if (line.isEmpty) continue;

      if (line.contains('||')) {
        final parts = line.split('||');
        currentCommit = parts[0];
        currentMsg = parts.sublist(1).join('||');
        commitLayers[currentCommit] = {};
        commitMessages[currentCommit] = currentMsg;
        continue;
      }

      if (currentCommit.isNotEmpty) {
        // Line is a file path
        for (final entry in layerRegexes.entries) {
          if (entry.value.hasMatch(line)) {
            commitLayers[currentCommit]!.add(entry.key);
          }
        }
      }
    }

    final driftCommits = <Map<String, dynamic>>[];

    for (final entry in commitLayers.entries) {
      final layers = entry.value.toList()..sort();
      if (layers.length > 1) {
        driftCommits.add({
          'hash': entry.key,
          'message': commitMessages[entry.key],
          'layers_coupled': layers,
        });

        for (int i = 0; i < layers.length; i++) {
          for (int j = i + 1; j < layers.length; j++) {
            final l1 = layers[i];
            final l2 = layers[j];
            couplingMatrix.putIfAbsent(l1, () => {});
            couplingMatrix[l1]![l2] = (couplingMatrix[l1]![l2] ?? 0) + 1;

            couplingMatrix.putIfAbsent(l2, () => {});
            couplingMatrix[l2]![l1] = (couplingMatrix[l2]![l1] ?? 0) + 1;
          }
        }
      }
    }

    final totalAnalyzed = commitLayers.length;
    final layerNames = layerRegexes.keys.toList();
    final numLayers = layerNames.length;

    // Coupling density: fraction of possible layer pairs that are coupled.
    final maxPairs = numLayers > 1 ? numLayers * (numLayers - 1) ~/ 2 : 0;
    int coupledPairCount = 0;
    for (final row in couplingMatrix.values) {
      coupledPairCount += row.length;
    }
    // Matrix is symmetric — each pair is counted twice.
    coupledPairCount ~/= 2;
    final couplingDensity = maxPairs > 0 ? coupledPairCount / maxPairs : 0.0;

    // Coupling ratio: share of commits that violate layer boundaries.
    final couplingRatio =
        totalAnalyzed > 0 ? driftCommits.length / totalAnalyzed : 0.0;

    // Architectural smell detection.
    final smells = <Map<String, dynamic>>[];

    if (driftCommits.isNotEmpty) {
      // God Component: a layer involved in > 50 % of drift commits.
      final layerDriftCount = <String, int>{};
      for (final dc in driftCommits) {
        for (final l in dc['layers_coupled'] as List<dynamic>) {
          layerDriftCount[l as String] = (layerDriftCount[l] ?? 0) + 1;
        }
      }
      for (final entry in layerDriftCount.entries) {
        if (entry.value > driftCommits.length * 0.5) {
          smells.add({
            'type': 'God Component',
            'layer': entry.key,
            'description':
                'Layer "${entry.key}" appears in ${entry.value}/${driftCommits.length} '
                    'drift commits. It has too many cross-cutting concerns and likely '
                    'violates the Single Responsibility Principle at the architecture level.',
          });
        }
      }

      // Hub-Like Dependency: a layer coupling with >= half of all other layers
      // (only meaningful when there are 4+ layers).
      if (numLayers >= 4) {
        for (final entry in couplingMatrix.entries) {
          final degree = entry.value.length;
          if (degree >= numLayers / 2) {
            smells.add({
              'type': 'Hub-Like Dependency',
              'layer': entry.key,
              'description':
                  'Layer "${entry.key}" is coupled with $degree/${numLayers - 1} '
                      'other layers, acting as a central coupling hub and introducing '
                      'fragility.',
            });
          }
        }
      }

      // Scattered Functionality: commits that touch 3 or more layers at once.
      final scattered = driftCommits
          .where((dc) => (dc['layers_coupled'] as List).length >= 3)
          .length;
      if (scattered > 0) {
        smells.add({
          'type': 'Scattered Functionality',
          'count': scattered,
          'description':
              '$scattered commits simultaneously modify 3 or more layers, '
                  'suggesting business logic or infrastructure concerns that are not '
                  'cleanly assigned to a single layer.',
        });
      }
    }

    return jsonEncode({
      'total_commits_analyzed': totalAnalyzed,
      'commits_with_drift': driftCommits.length,
      'coupling_ratio': double.parse(couplingRatio.toStringAsFixed(3)),
      'coupling_density': double.parse(couplingDensity.toStringAsFixed(3)),
      'coupling_matrix': couplingMatrix,
      'architectural_smells': smells,
      'drift_commits': driftCommits,
    });
  }
}
