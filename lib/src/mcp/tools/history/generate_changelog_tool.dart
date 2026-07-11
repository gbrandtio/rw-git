import 'dart:convert';
import 'dart:isolate';
import '../../../../rw_git.dart';
import '../../../constants.dart';
import '../../../vcs/git_query.dart';
import '../../utils/mcp_argument_extensions.dart';

/// generate_changelog_tool.dart
/// Generates a structured changelog from commit messages. Uses the shared
/// RA-SZZ core ([SzzAlgorithm.traceFixCommit]) to link bug fixes to their
/// introducing commits, and includes structural file impact for LLM
/// summarization.

class GenerateChangelogTool implements McpTool {
  final GitQuery gitQuery;
  final SzzAlgorithm szzAlgorithm;

  GenerateChangelogTool(this.gitQuery, this.szzAlgorithm);

  @override
  String get name => 'generate_changelog';

  @override
  String get description =>
      'Generates a structured changelog between two tags '
      'or commits. Enriches the output with RA-SZZ algorithm '
      'results (linking fixes to bug-introducing commits) '
      'and structural impact (changed files) for deep '
      'LLM summarization. '
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
      'from': {
        'type': 'string',
        'description': 'The starting tag or commit hash.',
      },
      'to': {'type': 'string', 'description': 'The ending tag or commit hash.'},
    },
    'required': ['directory', 'from', 'to'],
  };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments.getStringArgument('directory');
    final from = arguments.getStringArgument('from');
    final toReference = arguments.getStringArgument('to');

    final logRaw = (await gitQuery.run(directory, [
      'log',
      '$from..$toReference',
      '--format=%H||%an||%s',
    ])).getOrThrow();

    final parsed = await Isolate.run(() => parseConventionalCommits(logRaw));

    // Enrich fixes with SZZ outputs
    final enrichedFixes = <Map<String, dynamic>>[];
    for (final dynamic fixDyn in parsed['fixes'] as List? ?? []) {
      final fix = fixDyn as Map<String, dynamic>;
      final hash = fix['hash']!;
      final introducingCommits = await _runSzzForCommit(directory, hash);
      final changedFiles = await _getChangedFiles(directory, hash);

      enrichedFixes.add({
        'hash': hash,
        'author': fix['author'],
        'message': fix['message'],
        'bug_introducing_commits': introducingCommits,
        'changed_files': changedFiles,
      });
    }

    // Enrich features and other with changed files
    final enrichedFeatures = <Map<String, dynamic>>[];
    for (final dynamic featDyn in parsed['features'] as List? ?? []) {
      final feat = featDyn as Map<String, dynamic>;
      final hash = feat['hash']!;
      final changedFiles = await _getChangedFiles(directory, hash);
      enrichedFeatures.add({
        'hash': hash,
        'author': feat['author'],
        'message': feat['message'],
        'changed_files': changedFiles,
      });
    }

    final enrichedBreaking = <Map<String, dynamic>>[];
    for (final dynamic breakingChangeDyn
        in parsed['breaking_changes'] as List? ?? []) {
      final breakingChange = breakingChangeDyn as Map<String, dynamic>;
      final hash = breakingChange['hash']!;
      final changedFiles = await _getChangedFiles(directory, hash);
      enrichedBreaking.add({
        'hash': hash,
        'author': breakingChange['author'],
        'message': breakingChange['message'],
        'changed_files': changedFiles,
      });
    }

    final enrichedOther = <Map<String, dynamic>>[];
    for (final dynamic otherChangeDyn in parsed['other'] as List? ?? []) {
      final otherChange = otherChangeDyn as Map<String, dynamic>;
      final hash = otherChange['hash']!;
      final changedFiles = await _getChangedFiles(directory, hash);
      enrichedOther.add({
        'hash': hash,
        'author': otherChange['author'],
        'message': otherChange['message'],
        'changed_files': changedFiles,
      });
    }

    final contributors = <String>{};
    for (final feat in enrichedFeatures) {
      contributors.add(feat['author']);
    }
    for (final fix in enrichedFixes) {
      contributors.add(fix['author']);
    }
    for (final breakingChange in enrichedBreaking) {
      contributors.add(breakingChange['author']);
    }
    for (final otherChange in enrichedOther) {
      contributors.add(otherChange['author']);
    }
    contributors.removeWhere((c) => c.isEmpty);

    final totalCommits =
        enrichedFeatures.length +
        enrichedFixes.length +
        enrichedBreaking.length +
        enrichedOther.length;

    final Map<String, dynamic> result = {
      'total_commits': totalCommits,
      'contributors': contributors.toList()..sort(),
      'features': enrichedFeatures,
      'fixes': enrichedFixes,
      'breaking_changes': enrichedBreaking,
      'other': enrichedOther,
    };

    final includeRaw = arguments['includeRawMessages'] as bool? ?? false;
    if (includeRaw) {
      result['raw_log'] = logRaw;
    }

    return jsonEncode(result);
  }

  Future<List<String>> _getChangedFiles(String directory, String commit) async {
    final res = await gitQuery.run(directory, [
      'show',
      '--name-only',
      '--format=',
      commit,
    ]);
    if (res.isFailure) return [];
    final out = res.getOrThrow().trim();
    if (out.isEmpty) return [];
    return out
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  /// Links a fix commit to its introducing commits via the shared RA-SZZ
  /// core, then flattens the per-line matches into one entry per introducing
  /// commit with the temporal context the changelog contract documents
  /// (`introduced_date`, `days_bug_lived`).
  Future<List<Map<String, dynamic>>> _runSzzForCommit(
    String directory,
    String commit,
  ) async {
    final matches = await szzAlgorithm.traceFixCommit(directory, commit);

    final byIntroducingHash = <String, Map<String, dynamic>>{};
    for (final match in matches) {
      byIntroducingHash.putIfAbsent(match.introducingCommitHash, () {
        final daysBugLived =
            match.fixingDate.difference(match.introducingDate).inMinutes /
            minutesPerDay;
        return {
          'introducing_commit': match.introducingCommitHash,
          'introduced_date': match.introducingDate.toIso8601String(),
          'days_bug_lived': double.parse(daysBugLived.toStringAsFixed(2)),
        };
      });
    }
    return byIntroducingHash.values.toList();
  }
}
