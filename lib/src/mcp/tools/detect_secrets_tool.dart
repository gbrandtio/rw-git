import '../../quality/code_quality_tracker.dart';
import '../mcp_tool.dart';
import '../../constants.dart';

/// detect_secrets_tool.dart
/// Scans commit history for exposed secrets, API keys, or credentials.

class DetectSecretsTool implements McpTool {
  final CodeQualityTracker tracker;

  DetectSecretsTool(this.tracker);

  @override
  String get name => 'detect_secrets_in_commits';

  @override
  String get description => 'Scans commit deltas (or entire branches) using '
      'Isolates for exposed secrets, API keys, or sensitive credentials '
      'before they are pushed or merged. Returns a list of detected secrets '
      'with commit hashes and file names.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'directory': {
            'type': 'string',
            'description': 'The absolute path to the local git repository.',
          },
          'limit': {
            'type': 'string',
            'description': 'Optional. The number of commits to scan (e.g. "10"). '
                'Defaults to $defaultCommitLimit. If omitted, scans up to the limit of the given branch.',
          },
          'branch': {
            'type': 'string',
            'description': 'Optional. The branch or commit range to scan. '
                'If omitted, scans the current HEAD.',
          },
        },
        'required': ['directory'],
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments['directory'];
    if (directory == null || directory is! String) {
      throw ArgumentError(
          'The "directory" argument is required and must be a string.');
    }

    final limit = arguments['limit']?.toString() ?? defaultCommitLimit;
    final branch = arguments['branch']?.toString();

    final secrets =
        await tracker.findSecrets(directory, limit: limit, branch: branch);

    if (secrets.isEmpty) {
      return 'No exposed secrets or sensitive credentials found.';
    }

    final buffer = StringBuffer();
    buffer.writeln('⚠️ WARNING: Potential secrets exposed in commit history!');
    buffer.writeln('-' * 60);
    for (final secret in secrets) {
      buffer.writeln(secret);
      buffer.writeln('-' * 60);
    }

    return buffer.toString();
  }
}
