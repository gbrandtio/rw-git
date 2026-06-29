import 'dart:convert';
import 'dart:isolate';
import '../../../rw_git.dart';
import '../../constants.dart';

/// analyze_pr_diff_tool.dart
/// Analyzes a PR diff for risk signals by combining
/// churn, bus factor, and secret detection data.

class AnalyzePrDiffTool implements McpTool {
  final CodeQualityTracker tracker;
  final RwGit rwGit;

  AnalyzePrDiffTool(this.tracker, this.rwGit);

  @override
  String get name => 'analyze_pr_diff';

  @override
  String get description => 'Analyzes the diff between a base and head branch '
      '(or commit range) for code review risk signals. '
      'Returns per-file risk scores computed from churn '
      'history, bus factor, and secret exposure. '
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
          'base': {
            'type': 'string',
            'description': 'The base branch or commit hash.',
          },
          'head': {
            'type': 'string',
            'description': 'The head branch or commit hash.',
          },
          'topN': {
            'type': 'number',
            'description': 'Limits risk-ranked file output. '
                'Defaults to all changed files.',
          },
        },
        'required': ['directory', 'base', 'head'],
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments['directory'] as String;
    final base = arguments['base'] as String;
    final head = arguments['head'] as String;
    final topN = arguments['topN'] as int?;

    // 1. Get numstat and raw diff for the PR range
    final numstatRaw = (await rwGit.runCommand(
      directory,
      ['diff', '--numstat', '$base...$head'],
    ))
        .getOrThrow();

    final diffRaw = (await rwGit.runCommand(
      directory,
      ['diff', '-U0', '$base...$head'],
    ))
        .getOrThrow();

    // 2. Get churn data for risk scoring
    final churn = await tracker.calculateChurnWithAuthors(
      directory,
      limit: defaultCommitLimit,
    );

    // 3. Scan for secrets in the PR range
    final secretsRaw = (await rwGit.runCommand(
      directory,
      ['log', '-p', '--format=%H||%an||%ad||%s', '$base..$head'],
    ))
        .getOrThrow();

    // 4. Parse and score in an Isolate
    final churnMap = <String, int>{};
    final busFactorMap = <String, double>{};
    for (final entry in churn.fileChurn.entries) {
      churnMap[entry.key] = entry.value.total;
      if (entry.value.authors.isNotEmpty) {
        final topAuthorChanges = entry.value.authors.values.reduce(
          (a, b) => a > b ? a : b,
        );
        busFactorMap[entry.key] = topAuthorChanges / entry.value.total;
      }
    }

    final result = await Isolate.run(
      () => _scorePrDiff(
        numstatRaw,
        diffRaw,
        churnMap,
        busFactorMap,
        secretsRaw,
        topN,
      ),
    );

    return jsonEncode(result);
  }
}

// -----------------------------------------------------------------------------
// Isolate entry point
// -----------------------------------------------------------------------------

Map<String, dynamic> _scorePrDiff(
  String numstatRaw,
  String diffRaw,
  Map<String, int> churnMap,
  Map<String, double> busFactorMap,
  String secretsRaw,
  int? topN,
) {
  // Parse secret regex to find files with secrets
  final secretFiles = <String>{};
  final secretRegex = RegExp(
    r'(?:'
    r'AKIA[0-9A-Z]{16}|'
    r'xox[baprs]-[0-9a-zA-Z]{10,48}|'
    r'(?:sk|pk)_(?:test|live)_[0-9a-zA-Z]{24}|'
    r'-----BEGIN (?:RSA|DSA|EC|OPENSSH|PGP) PRIVATE KEY-----|'
    r'ey[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}|'
    r'(?:api_key|apikey|secret|password|passwd|token|auth)[^a-zA-Z0-9]{1,3}[a-zA-Z0-9_\-\.]{12,}'
    r')',
    caseSensitive: false,
  );

  String currentFile = '';
  for (final line in secretsRaw.split('\n')) {
    if (line.startsWith('+++ b/')) {
      currentFile = line.substring(6).trim();
    } else if (line.startsWith('+') && !line.startsWith('+++')) {
      if (secretRegex.hasMatch(line)) {
        secretFiles.add(currentFile);
      }
    }
  }

  // Parse diff for structural hunks
  final hunksPerFile = <String, int>{};
  final structuralHunksPerFile = <String, List<String>>{};
  String currentDiffFile = '';

  for (final line in diffRaw.split('\n')) {
    if (line.startsWith('+++ b/')) {
      currentDiffFile = line.substring(6).trim();
      hunksPerFile.putIfAbsent(currentDiffFile, () => 0);
      structuralHunksPerFile.putIfAbsent(currentDiffFile, () => []);
    } else if (line.startsWith('@@ ')) {
      if (currentDiffFile.isNotEmpty) {
        hunksPerFile[currentDiffFile] =
            (hunksPerFile[currentDiffFile] ?? 0) + 1;
        final parts = line.split('@@');
        if (parts.length >= 3) {
          final context = parts.sublist(2).join('@@').trim();
          if (context.isNotEmpty) {
            structuralHunksPerFile[currentDiffFile]!.add(context);
          }
        }
      }
    }
  }

  // Parse numstat and compute risk
  final changedFiles = <Map<String, dynamic>>[];
  final numstatLines = numstatRaw.split('\n');

  // Find max churn for normalization
  final maxChurn = churnMap.values.isEmpty
      ? 1
      : churnMap.values.reduce((a, b) => a > b ? a : b);

  for (final line in numstatLines) {
    if (line.trim().isEmpty) continue;
    final parts = line.split('\t');
    if (parts.length < 3) continue;

    final added = int.tryParse(parts[0].trim()) ?? 0;
    final removed = int.tryParse(parts[1].trim()) ?? 0;
    final file = parts[2].trim();

    final fileChurn = churnMap[file] ?? 0;
    final busFactorRatio = busFactorMap[file] ?? 0.0;
    final hasSecret = secretFiles.contains(file);

    // Composite risk: 0.0 to 1.0
    // - 30% weight: change magnitude (lines)
    // - 10% weight: structural complexity (hunks)
    // - 30% weight: historical churn (normalized)
    // - 20% weight: bus factor concentration
    // - 10% weight: secret exposure
    final hunks = hunksPerFile[file] ?? 0;
    final structHunks = structuralHunksPerFile[file] ?? [];

    final changeMagnitude = (added + removed) / 1000.0;
    final structuralMagnitude = hunks / 50.0;
    final churnScore = fileChurn / maxChurn;
    final busScore = busFactorRatio;
    final secretScore = hasSecret ? 1.0 : 0.0;

    final risk = (changeMagnitude.clamp(0.0, 1.0) * 0.3) +
        (structuralMagnitude.clamp(0.0, 1.0) * 0.1) +
        (churnScore.clamp(0.0, 1.0) * 0.3) +
        (busScore.clamp(0.0, 1.0) * 0.2) +
        (secretScore * 0.1);

    changedFiles.add({
      'file': file,
      'added': added,
      'removed': removed,
      'risk_score': double.parse(
        risk.clamp(0.0, 1.0).toStringAsFixed(3),
      ),
      'hunks': hunks,
      'structural_contexts': structHunks.take(3).toList(),
      'churn_rank': fileChurn,
      'bus_factor_risk': double.parse(
        busFactorRatio.toStringAsFixed(3),
      ),
      'has_secret_exposure': hasSecret,
    });
  }

  // Sort by risk descending
  changedFiles.sort(
    (a, b) => (b['risk_score'] as double).compareTo(a['risk_score'] as double),
  );

  final output = topN != null && changedFiles.length > topN
      ? changedFiles.take(topN).toList()
      : changedFiles;

  // Determine overall risk level
  final maxRisk = output.isEmpty ? 0.0 : output.first['risk_score'] as double;
  String overallRisk;
  if (maxRisk >= 0.7) {
    overallRisk = 'high';
  } else if (maxRisk >= 0.4) {
    overallRisk = 'medium';
  } else {
    overallRisk = 'low';
  }

  return {
    'total_files_changed': changedFiles.length,
    'overall_risk_level': overallRisk,
    'changed_files': output,
  };
}
