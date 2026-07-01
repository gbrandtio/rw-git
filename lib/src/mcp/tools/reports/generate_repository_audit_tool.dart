import 'dart:convert';
import '../../../../rw_git.dart';
import '../../../constants.dart';
import '../../utils/mcp_argument_extensions.dart';

/// generate_repository_audit_tool.dart
/// One-call high-level deep audit (technical + security) for small/local
/// models — the pass where cross-tool compound findings surface best.
class GenerateRepositoryAuditTool implements McpTool {
  final ProcessRunner runner;
  final RwHttpClient httpClient;

  GenerateRepositoryAuditTool(this.runner, {RwHttpClient? httpClient})
      : httpClient = httpClient ??
            RwHttpClient.defaultClient(interceptors: [RetryInterceptor()]);

  @override
  String get name => 'generate_repository_audit';

  @override
  String get description =>
      'One-call deep audit combining technical + security in a single pass; '
      'the best pass for cross-tool compound risks. Returns pre-classified, '
      'ranked findings to narrate directly.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'directory': {
            'type': 'string',
            'description': 'The local repository path.',
          },
          'limit': {
            'type': 'number',
            'description':
                'Max recent commits to analyze (default: $defaultCommitLimit).',
          },
          'branch': {
            'type': 'string',
            'description': 'Optional. Branch or commit range to scan for '
                'secrets. Defaults to current HEAD.',
          },
          'check_freshness': {
            'type': 'boolean',
            'description': 'Optional. When true, performs network lookups '
                'against package registries to flag outdated dependencies. '
                'Default false (fully offline).',
          },
          'allowed_emails': {
            'type': 'string',
            'description': 'Optional. Comma-separated allow-list of author '
                'emails for the compliance check.',
          },
        },
        'required': ['directory'],
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments.getStringArgument('directory');
    final limit = arguments['limit']?.toString() ?? defaultCommitLimit;
    final branch = arguments['branch']?.toString();
    final checkFreshness =
        arguments.getOptionalBoolArgument('check_freshness') ?? false;
    final allowedEmails = (arguments['allowed_emails']?.toString() ?? '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final payload = await ReportOrchestrator(runner, httpClient: httpClient)
        .repositoryAudit(
      directory,
      limit: limit,
      branch: branch,
      checkFreshness: checkFreshness,
      allowedEmails: allowedEmails,
    );
    return jsonEncode(payload.toJson());
  }
}
