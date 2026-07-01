/// ----------------------------------------------------------------------------
/// compliance_classifier.dart
/// ----------------------------------------------------------------------------
library;

import 'package:rw_git/src/models/compliance_report_dto.dart';

import '../finding.dart';
import '../severity.dart';

/// Classifies commit-compliance violations (signing, message hygiene, author
/// domains) into aggregate severity bands, one finding per violation type.
class ComplianceClassifier {
  const ComplianceClassifier();

  List<Finding> classify(ComplianceReportDto dto) {
    final findings = <Finding>[];

    void add(
      List<ComplianceViolation> violations,
      String metric,
      Severity severity,
      String label,
    ) {
      if (violations.isEmpty) return;
      findings.add(Finding(
        category: 'compliance',
        source: 'audit_compliance',
        severity: severity,
        subject: 'repository',
        metric: metric,
        value: violations.length,
        band: '${violations.length} $label',
        message: '${violations.length} $label out of '
            '${dto.totalCommitsScanned} commits scanned.',
        evidence: {
          'count': violations.length,
          'total_commits_scanned': dto.totalCommitsScanned,
          'sample_hashes': violations.take(5).map((v) => v.hash).toList(),
        },
      ));
    }

    add(dto.unsignedCommits, 'unsigned_commits', Severity.moderate,
        'unsigned commit(s)');
    add(dto.unrecognizedAuthorCommits, 'unrecognized_author_commits',
        Severity.moderate, 'commit(s) from unrecognised authors');
    add(dto.emptyMessageCommits, 'empty_message_commits', Severity.low,
        'empty-message commit(s)');
    add(dto.nonConventionalCommits, 'non_conventional_commits', Severity.low,
        'non-conventional commit message(s)');

    return findings;
  }
}
