import 'dart:isolate';
import 'package:rw_git/src/core/process_runner.dart';
import 'package:rw_git/src/models/compliance_report_dto.dart';

/// ----------------------------------------------------------------------------
/// compliance_scanner.dart
/// ----------------------------------------------------------------------------
class ComplianceScanner {
  final ProcessRunner runner;

  ComplianceScanner(this.runner);

  /// Scans commit history for compliance policy violations.
  Future<ComplianceReportDto> scanComplianceIssues(
    String directory, {
    String? limit,
    String? since,
    String? until,
    List<String> allowedEmails = const [],
  }) async {
    final args = ['log', '--format=%H||%G?||%ae||%an||%aI||%s'];
    if (limit != null) {
      args.insert(1, '-n');
      args.insert(2, limit);
    }
    if (since != null) {
      args.add('--since=$since');
    }
    if (until != null) {
      args.add('--until=$until');
    }

    final result = await runner.run('git', args, workingDirectory: directory);
    evaluateProcessResult(result);
    final rawOutput = result.stdout?.toString() ?? '';

    return await Isolate.run(
      () => _parseComplianceIssues(rawOutput, allowedEmails),
    );
  }
}

ComplianceReportDto _parseComplianceIssues(
  String rawLog,
  List<String> allowedEmails,
) {
  final lines = rawLog.split('\n');
  final unsigned = <ComplianceViolation>[];
  final emptyMsg = <ComplianceViolation>[];
  final unrecognized = <ComplianceViolation>[];
  final nonConventional = <ComplianceViolation>[];
  int total = 0;

  final allowedSet = allowedEmails.toSet();

  // Regex for Conventional Commits
  final conventionalRegex = RegExp(
    r'^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\([a-z0-9\-]+\))?!?: .+',
    caseSensitive: false,
  );

  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final parts = line.split('||');
    // Format: %H||%G?||%ae||%an||%aI||%s
    if (parts.length < 6) continue;
    total++;

    final hash = parts[0].trim();
    final sigStatus = parts[1].trim();
    final email = parts[2].trim();
    final author = parts[3].trim();
    final date = parts[4].trim();
    final message = parts.sublist(5).join('||').trim();

    final violation = ComplianceViolation(
      hash: hash,
      author: author,
      email: email,
      message: message,
      date: date,
    );

    // N = no signature, U = untrusted, E = expired,
    // X = expired key, R = revoked, B = bad
    // G = good, empty = no check
    if (sigStatus != 'G') {
      unsigned.add(violation);
    }

    if (message.isEmpty) {
      emptyMsg.add(violation);
    } else if (!conventionalRegex.hasMatch(message) &&
        !message.startsWith('Merge ')) {
      nonConventional.add(violation);
    }

    if (allowedSet.isNotEmpty && !allowedSet.contains(email)) {
      unrecognized.add(violation);
    }
  }

  return ComplianceReportDto(
    totalCommitsScanned: total,
    unsignedCommits: unsigned,
    emptyMessageCommits: emptyMsg,
    unrecognizedAuthorCommits: unrecognized,
    nonConventionalCommits: nonConventional,
  );
}

Map<String, List<Map<String, String>>> parseConventionalCommits(String rawLog) {
  final features = <Map<String, String>>[];
  final fixes = <Map<String, String>>[];
  final breakingChanges = <Map<String, String>>[];
  final other = <Map<String, String>>[];

  final lines = rawLog.split('\n');
  final conventionalRegex = RegExp(
    r'^(feat|fix|chore|docs|style|refactor|perf|test|build|ci|revert)'
    r'(\([^)]+\))?!?:\s*(.+)$',
    caseSensitive: false,
  );

  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final parts = line.split('||');
    if (parts.length < 3) continue;

    final hash = parts[0].trim();
    final author = parts[1].trim();
    final message = parts.sublist(2).join('||').trim();

    final entry = {'hash': hash, 'author': author, 'message': message};

    // Check for breaking changes
    if (message.toUpperCase().contains('BREAKING CHANGE') ||
        message.contains('!:')) {
      breakingChanges.add(entry);
      continue;
    }

    final match = conventionalRegex.firstMatch(message);
    if (match != null) {
      final type = match.group(1)!.toLowerCase();
      switch (type) {
        case 'feat':
          features.add(entry);
        case 'fix':
          fixes.add(entry);
        default:
          other.add(entry);
      }
    } else {
      other.add(entry);
    }
  }

  return {
    'features': features,
    'fixes': fixes,
    'breaking_changes': breakingChanges,
    'other': other,
  };
}
