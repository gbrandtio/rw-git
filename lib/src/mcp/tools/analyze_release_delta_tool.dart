import 'dart:convert';
import 'dart:isolate';
import '../../../rw_git.dart';

/// analyze_release_delta_tool.dart
/// Analyzes the release delta and velocity between two stable tags.

class AnalyzeReleaseDeltaTool implements McpTool {
  final RwGit rwGit;

  AnalyzeReleaseDeltaTool(this.rwGit);

  @override
  String get name => 'analyze_release_delta';

  @override
  String get description =>
      'Quantifies changes, file updates, and delta commits between two tags. '
      'Returns a structured JSON summary to save tokens. Set `detailed: true` '
      'if you need the full raw commit logs included in the response. '
      'For a complete guide on how to use the rw_git MCP tools, invoke the get_rw_git_documentation tool.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'localCheckoutDirectory': {
            'type': 'string',
            'description': 'The local directory containing the git repository.'
          },
          'firstTag': {
            'type': 'string',
            'description': 'The older tag or commit hash.'
          },
          'secondTag': {
            'type': 'string',
            'description': 'The newer tag or commit hash.'
          },
          'detailed': {
            'type': 'boolean',
            'description':
                'If true, includes the full list of commits in the response. Defaults to false.'
          }
        },
        'required': ['localCheckoutDirectory', 'firstTag', 'secondTag']
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final localDir = arguments['localCheckoutDirectory'] as String;
    final firstTag = arguments['firstTag'] as String;
    final secondTag = arguments['secondTag'] as String;
    final detailed = arguments['detailed'] as bool? ?? false;

    // 1. Get all commits and authors
    final logRaw = await rwGit.runCommand(localDir,
        ['log', '$firstTag..$secondTag', '--format=%H||%an||%ad||%s']);

    // 2. Get file diff stats
    final numstatRaw = await rwGit
        .runCommand(localDir, ['diff', '--numstat', firstTag, secondTag]);

    // Offload parsing to an Isolate
    final resultMap = await Isolate.run(
        () => _parseReleaseDelta(logRaw, numstatRaw, detailed));

    return jsonEncode(resultMap);
  }
}

// -----------------------------------------------------------------------------
// ISOLATE ENTRY POINTS (Must be static or top-level)
// -----------------------------------------------------------------------------

Map<String, dynamic> _parseReleaseDelta(
    String logRaw, String numstatRaw, bool detailed) {
  int totalCommits = 0;
  final Map<String, int> authors = {};
  final List<String> rawCommits = [];

  final logLines = logRaw.split('\n');
  for (final line in logLines) {
    if (line.trim().isEmpty) continue;
    totalCommits++;
    final parts = line.split('||');
    if (parts.length >= 2) {
      final author = parts[1].trim();
      authors[author] = (authors[author] ?? 0) + 1;
    }
    if (detailed) {
      rawCommits.add(line);
    }
  }

  int totalInsertions = 0;
  int totalDeletions = 0;
  final List<_FileStat> fileStats = [];

  final statLines = numstatRaw.split('\n');
  for (final line in statLines) {
    if (line.trim().isEmpty) continue;
    final parts = line.split('\t');
    if (parts.length >= 3) {
      final added = int.tryParse(parts[0].trim()) ?? 0;
      final removed = int.tryParse(parts[1].trim()) ?? 0;
      final file = parts[2].trim();
      totalInsertions += added;
      totalDeletions += removed;
      fileStats.add(_FileStat(file, added, removed));
    }
  }

  fileStats.sort((a, b) => b.totalChanges.compareTo(a.totalChanges));

  // Top 10 modified files
  final topModifiedFiles = fileStats
      .take(10)
      .map((fs) => {
            'file': fs.fileName,
            'added': fs.added,
            'removed': fs.removed,
            'totalChanges': fs.totalChanges
          })
      .toList();

  final Map<String, dynamic> result = {
    'total_commits': totalCommits,
    'total_insertions': totalInsertions,
    'total_deletions': totalDeletions,
    'files_changed': fileStats.length,
    'active_contributors': authors.length,
    'top_modified_files': topModifiedFiles,
    'authors_breakdown': authors,
  };

  if (detailed) {
    result['commits'] = rawCommits;
  }

  return result;
}

class _FileStat {
  final String fileName;
  final int added;
  final int removed;

  _FileStat(this.fileName, this.added, this.removed);

  int get totalChanges => added + removed;
}
