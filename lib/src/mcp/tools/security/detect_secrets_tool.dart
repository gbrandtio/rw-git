import 'dart:convert';
import '../../../intelligence/security/secrets_scanner.dart';
import 'package:rw_git/src/core/process_runner.dart';
import '../../mcp_tool.dart';
import '../../../constants.dart';

/// detect_secrets_tool.dart
/// Scans commit history for exposed secrets, API keys, or credentials.

class DetectSecretsTool implements McpTool {
  final ProcessRunner runner;

  DetectSecretsTool(this.runner);

  @override
  String get name => 'detect_secrets_in_commits';

  @override
  String get description =>
      'Scans commit deltas (or entire branches) using '
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
        'description':
            'Optional. The number of commits to scan (e.g. "10"). '
            'Defaults to $defaultCommitLimit. If omitted, scans up to the limit of the given branch.',
      },
      'branch': {
        'type': 'string',
        'description':
            'Optional. The branch or commit range to scan. '
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
        'The "directory" argument is required and must be a string.',
      );
    }

    final limit = arguments['limit']?.toString() ?? defaultCommitLimit;
    final branch = arguments['branch']?.toString();

    final secrets = await SecretsScanner(
      runner,
    ).findSecrets(directory, limit: limit, branch: branch);

    if (secrets.isEmpty) {
      return jsonEncode({
        'secrets_found': 0,
        'message': 'No exposed secrets or sensitive credentials found.',
      });
    }

    return jsonEncode({
      'secrets_found': secrets.length,
      'message':
          'WARNING: Potential secrets exposed in commit history! '
          'Values are redacted. Review each finding immediately.',
      'findings': secrets,
    });
  }
}
