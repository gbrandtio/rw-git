import '../../../intelligence/security/compliance_scanner.dart';
import 'dart:convert';
import 'dart:isolate';
import '../../../../rw_git.dart';
import '../../utils/mcp_argument_extensions.dart';

/// generate_changelog_tool.dart
/// Generates a structured changelog from commit
/// messages. Uses SZZ to link bug fixes to their introducing
/// commits, and includes structural file impact for LLM summarization.

class GenerateChangelogTool implements McpTool {
  final RwGit rwGit;

  GenerateChangelogTool(this.rwGit);

  @override
  String get name => 'generate_changelog';

  @override
  String get description => 'Generates a structured changelog between two tags '
      'or commits. Enriches the output with SZZ algorithm '
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
          'to': {
            'type': 'string',
            'description': 'The ending tag or commit hash.',
          },
        },
        'required': ['directory', 'from', 'to'],
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments.getStringArgument('directory');
    final from = arguments.getStringArgument('from');
    final to = arguments.getStringArgument('to');

    final logRaw = (await rwGit.runCommand(
      directory,
      [
        'log',
        '$from..$to',
        '--format=%H||%an||%s',
      ],
    ))
        .getOrThrow();

    final parsed = await Isolate.run(
      () => parseConventionalCommits(logRaw),
    );

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
    for (final dynamic bDyn in parsed['breaking_changes'] as List? ?? []) {
      final b = bDyn as Map<String, dynamic>;
      final hash = b['hash']!;
      final changedFiles = await _getChangedFiles(directory, hash);
      enrichedBreaking.add({
        'hash': hash,
        'author': b['author'],
        'message': b['message'],
        'changed_files': changedFiles,
      });
    }

    final enrichedOther = <Map<String, dynamic>>[];
    for (final dynamic oDyn in parsed['other'] as List? ?? []) {
      final o = oDyn as Map<String, dynamic>;
      final hash = o['hash']!;
      final changedFiles = await _getChangedFiles(directory, hash);
      enrichedOther.add({
        'hash': hash,
        'author': o['author'],
        'message': o['message'],
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
    for (final b in enrichedBreaking) {
      contributors.add(b['author']);
    }
    for (final o in enrichedOther) {
      contributors.add(o['author']);
    }
    contributors.removeWhere((c) => c.isEmpty);

    final totalCommits = enrichedFeatures.length +
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
    final res = await rwGit.runCommand(
      directory,
      ['show', '--name-only', '--format=', commit],
    );
    if (res.isFailure) return [];
    final out = res.getOrThrow().trim();
    if (out.isEmpty) return [];
    return out
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  Future<List<String>> _runSzzForCommit(String directory, String commit) async {
    final introducing = <String>{};

    final parentRes =
        await rwGit.runCommand(directory, ['rev-parse', '$commit^']);
    if (parentRes.isFailure) return [];
    final parent = parentRes.getOrThrow().trim();
    if (parent.isEmpty) return [];

    final diffRes = await rwGit.runCommand(directory, ['diff', parent, commit]);
    if (diffRes.isFailure) return [];

    final diffOutput = diffRes.getOrThrow().split('\n');
    String currentFile = '';

    for (final line in diffOutput) {
      if (line.startsWith('--- a/')) {
        currentFile = line.substring(6).trim();
      } else if (line.startsWith('@@ ') &&
          currentFile.isNotEmpty &&
          currentFile != '/dev/null') {
        final parts = line.split(' ');
        if (parts.length < 2) continue;
        final minusPart = parts[1]; // -start,count
        if (!minusPart.startsWith('-')) continue;

        final minusParts = minusPart.substring(1).split(',');
        final start = int.tryParse(minusParts[0]) ?? 0;
        final count =
            minusParts.length > 1 ? (int.tryParse(minusParts[1]) ?? 1) : 1;

        if (count > 0 && start > 0) {
          final end = start + count - 1;
          final blameRes = await rwGit.runCommand(directory,
              ['blame', '-e', '-L', '$start,$end', parent, '--', currentFile]);
          if (blameRes.isSuccess) {
            final blameLines =
                blameRes.getOrThrow().split('\n').where((l) => l.isNotEmpty);
            for (final bLine in blameLines) {
              final match = RegExp(r'^([a-f0-9]+)\s+').firstMatch(bLine);
              if (match != null) {
                final blamedHash = match.group(1)!;
                // Exclude uncommitted changes or all zeros
                if (!blamedHash.startsWith('00000000')) {
                  introducing.add(blamedHash);
                }
              }
            }
          }
        }
      }
    }

    return introducing.toList();
  }
}
