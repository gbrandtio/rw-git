import 'dart:convert';
import 'dart:isolate';
import '../../../rw_git.dart';

/// generate_changelog_tool.dart
/// Generates a structured changelog from commit
/// messages using Conventional Commits conventions.

class GenerateChangelogTool implements McpTool {
  final RwGit rwGit;

  GenerateChangelogTool(this.rwGit);

  @override
  String get name => 'generate_changelog';

  @override
  String get description => 'Generates a structured changelog between two tags '
      'or commits using Conventional Commits conventions. '
      'Groups commits into features, fixes, breaking '
      'changes, and other. Falls back to ungrouped list '
      'if the repository does not follow Conventional '
      'Commits. '
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
          'includeRawMessages': {
            'type': 'boolean',
            'description': 'If true, includes raw commit messages '
                'in the output. Defaults to false.',
          },
        },
        'required': ['directory', 'from', 'to'],
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments['directory'] as String;
    final from = arguments['from'] as String;
    final to = arguments['to'] as String;
    final includeRaw = arguments['includeRawMessages'] as bool? ?? false;

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

    // Collect unique contributors
    final contributors = <String>{};
    for (final list in parsed.values) {
      for (final entry in list) {
        final author = entry['author'] ?? '';
        if (author.isNotEmpty) {
          contributors.add(author);
        }
      }
    }

    final totalCommits = parsed.values.fold<int>(0, (s, l) => s + l.length);

    final Map<String, dynamic> result = {
      'total_commits': totalCommits,
      'contributors': contributors.toList()..sort(),
      'features': parsed['features'] ?? [],
      'fixes': parsed['fixes'] ?? [],
      'breaking_changes': parsed['breaking_changes'] ?? [],
      'other': parsed['other'] ?? [],
    };

    if (includeRaw) {
      result['raw_log'] = logRaw;
    }

    return jsonEncode(result);
  }
}
