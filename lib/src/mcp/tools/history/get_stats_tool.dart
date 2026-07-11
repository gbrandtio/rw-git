import 'dart:convert';
import '../../../../rw_git.dart';
import '../../../vcs/git_query.dart';
import '../../utils/mcp_argument_extensions.dart';

/// get_stats_tool.dart
/// Gets statistics between two tags via MCP.

class GetStatsTool implements McpTool {
  final RwGit rwGit;
  final GitQuery gitQuery;

  GetStatsTool(this.rwGit, this.gitQuery);

  @override
  String get name => 'get_stats';

  @override
  String get description =>
      'Retrieves code statistics (insertions, deletions, files changed) between two tags, '
      'along with a breakdown of insertions and deletions grouped by file extension. '
      'For a complete guide on how to use the rw_git MCP tools, invoke the get_rw_git_documentation tool.';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'directory': {
        'type': 'string',
        'description': 'The local directory containing the git repository.',
      },
      'oldTag': {
        'type': 'string',
        'description': 'The older tag or commit hash.',
      },
      'newTag': {
        'type': 'string',
        'description': 'The newer tag or commit hash.',
      },
    },
    'required': ['directory', 'oldTag', 'newTag'],
  };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final localDir = arguments.getStringArgument('directory');
    final oldTag = arguments.getStringArgument('oldTag');
    final newTag = arguments.getStringArgument('newTag');
    final stats = (await rwGit.stats(localDir, oldTag, newTag)).getOrThrow();

    // Group insertions/deletions by file extension
    final numstatResult = (await gitQuery.run(localDir, [
      'diff',
      '--numstat',
      oldTag,
      newTag,
    ])).getOrThrow();

    final Map<String, Map<String, int>> statsByExtension = {};
    for (final line in numstatResult.split('\n')) {
      if (line.trim().isEmpty) continue;
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length >= 3) {
        final ins = int.tryParse(parts[0]) ?? 0;
        final del = int.tryParse(parts[1]) ?? 0;
        final fileName = parts.sublist(2).join(' ');

        final extIndex = fileName.lastIndexOf('.');
        final ext = (extIndex > 0 && extIndex < fileName.length - 1)
            ? fileName.substring(extIndex)
            : 'no_extension';

        statsByExtension.putIfAbsent(
          ext,
          () => {'insertions': 0, 'deletions': 0},
        );
        statsByExtension[ext]!['insertions'] =
            (statsByExtension[ext]!['insertions'] ?? 0) + ins;
        statsByExtension[ext]!['deletions'] =
            (statsByExtension[ext]!['deletions'] ?? 0) + del;
      }
    }

    return jsonEncode({
      'numberOfChangedFiles': stats.numberOfChangedFiles,
      'insertions': stats.insertions,
      'deletions': stats.deletions,
      'stats_by_extension': statsByExtension,
    });
  }
}
