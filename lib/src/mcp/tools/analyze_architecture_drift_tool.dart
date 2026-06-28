import 'dart:convert';
import '../../../rw_git.dart';

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
    final directory = arguments['directory'] as String;
    final layerPatternsMap =
        arguments['layer_patterns'] as Map<String, dynamic>;
    final since = arguments['since'] as String? ?? '90 days ago';

    final layerRegexes = <String, RegExp>{};
    for (final entry in layerPatternsMap.entries) {
      layerRegexes[entry.key] = RegExp(entry.value.toString());
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

    return jsonEncode({
      'total_commits_analyzed': commitLayers.length,
      'commits_with_drift': driftCommits.length,
      'coupling_matrix': couplingMatrix,
      'drift_commits': driftCommits,
    });
  }
}
