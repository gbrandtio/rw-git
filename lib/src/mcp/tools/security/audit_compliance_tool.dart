import 'dart:convert';
import '../../../../rw_git.dart';
import '../../../constants.dart';
import '../../utils/mcp_argument_extensions.dart';

/// audit_compliance_tool.dart
/// Scans commit history for compliance policy
/// violations (unsigned commits, empty messages,
/// unrecognized authors).

class AuditComplianceTool implements McpTool {
  final ProcessRunner runner;

  AuditComplianceTool(this.runner);

  @override
  String get name => 'audit_compliance';

  @override
  String get description => 'Scans commit history for compliance policy '
      'violations: unsigned commits (no GPG/SSH '
      'signature), empty commit messages, and commits '
      'from unrecognized author emails. Optionally '
      'supply an allowedEmails list to flag unknown '
      'contributors. '
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
          'limit': {
            'type': 'number',
            'description': 'Number of commits to scan '
                '(default: $defaultCommitLimit).',
          },
          'allowedEmails': {
            'type': 'string',
            'description': 'Comma-separated list of allowed '
                'author email addresses. Commits '
                'from other emails will be flagged.',
          },
        },
        'required': ['directory'],
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments.getStringArgument('directory');
    final limit = arguments['limit']?.toString() ?? defaultCommitLimit;
    final allowedEmailsStr =
        arguments.getOptionalStringArgument('allowedEmails');

    final allowedEmails =
        allowedEmailsStr != null && allowedEmailsStr.isNotEmpty
            ? allowedEmailsStr
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList()
            : <String>[];

    final report = await ComplianceScanner(runner).scanComplianceIssues(
      directory,
      limit: limit,
      allowedEmails: allowedEmails,
    );

    return jsonEncode({
      'total_commits_scanned': report.totalCommitsScanned,
      'total_violations': report.totalViolations,
      'unsigned_commits': report.unsignedCommits
          .map((v) => {
                'hash': v.hash,
                'author': v.author,
                'email': v.email,
                'date': v.date,
                'message': v.message,
              })
          .toList(),
      'empty_message_commits': report.emptyMessageCommits
          .map((v) => {
                'hash': v.hash,
                'author': v.author,
                'email': v.email,
                'date': v.date,
              })
          .toList(),
      'unrecognized_author_commits': report.unrecognizedAuthorCommits
          .map((v) => {
                'hash': v.hash,
                'author': v.author,
                'email': v.email,
                'date': v.date,
                'message': v.message,
              })
          .toList(),
      'non_conventional_commits': report.nonConventionalCommits
          .map((v) => {
                'hash': v.hash,
                'author': v.author,
                'email': v.email,
                'date': v.date,
                'message': v.message,
              })
          .toList(),
    });
  }
}
