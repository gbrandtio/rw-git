import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

/// Compound Rules 6-8: the author-level knowledge-loss join (Avelino 2016;
/// Fritz 2010; Mockus 2002), the Bird minor-contributor x hotspot join
/// (Bird et al. 2011), and the burnout x bug-introduction co-occurrence
/// (Claes 2018; Eyolfson 2011). These tests pin each rule's trigger
/// conditions so a change is a deliberate ADR-0010 act.
void main() {
  const fc = FindingClassifier();
  const correlator = CompoundFindingCorrelator();

  /// One file whose changes are >50% owned by [author] (Critical
  /// concentration), plus optionally many minor contributors.
  List<Finding> ownershipOn(
    String file, {
    String author = 'alice',
    int minorContributors = 0,
  }) {
    final authors = <String, int>{
      author: 100,
      for (var i = 0; i < minorContributors; i++) 'minor$i': 1,
    };
    final total = authors.values.fold<int>(0, (sum, value) => sum + value);
    return fc.fromOwnership(
      ChurnMetricsWithAuthorsDto(
        fileChurn: {file: ContributionStats(total: total, authors: authors)},
        totalCommits: total,
      ),
    );
  }

  /// Bug-hotspot findings for [files] (each above 2x the global lifetime).
  List<Finding> hotspotsOn(List<String> files) => fc.fromBugHotspots(
        BugHotspotDto(
          fileHotspots: {for (final f in files) f: 5},
          authorHotspots: const {},
          totalFixCommitsAnalyzed: files.length * 5,
          globalAverageBugLifetimeInDays: 10,
          fileAverageBugLifetimeInDays: {for (final f in files) f: 30},
          authorAverageBugLifetimeInDays: const {},
        ),
      );

  /// A High burnout finding (>15% of commits in the burnout window).
  List<Finding> burnoutFindings() => fc.fromCommitVelocity(
        const CommitVelocityDto(
          buckets: [],
          totalCommits: 100,
          averagePerPeriod: 10,
          trend: 'stable',
          anomalies: [],
          totalBurnoutCommits: 30,
          giniCoefficient: 0.2,
          velocitySlope: 1,
        ),
      );

  group('Rule 6: author-level knowledge loss', () {
    test('fires when one author solely owns 2+ bug-hotspot files', () {
      final findings = [
        ...ownershipOn('lib/a.dart'),
        ...ownershipOn('lib/b.dart'),
        ...hotspotsOn(['lib/a.dart', 'lib/b.dart']),
      ];

      final compound = correlator
          .correlate(findings)
          .singleWhere((c) => c.metric == 'knowledge_loss_risk');
      expect(compound.severity, Severity.critical);
      expect(compound.subject, 'alice');
      expect(compound.evidence['at_risk_files'], ['lib/a.dart', 'lib/b.dart']);
    });

    test('stays silent below the minimum file count', () {
      final findings = [
        ...ownershipOn('lib/a.dart'),
        ...hotspotsOn(['lib/a.dart']),
      ];

      expect(
        correlator
            .correlate(findings)
            .where((c) => c.metric == 'knowledge_loss_risk'),
        isEmpty,
      );
    });
  });

  group('Rule 7: minor contributors on a bug hotspot', () {
    test('fires High when a hotspot file has 3+ minor contributors', () {
      final findings = [
        ...ownershipOn('lib/hot.dart', minorContributors: 4),
        ...hotspotsOn(['lib/hot.dart']),
      ];

      final compound = correlator
          .correlate(findings)
          .singleWhere((c) => c.metric == 'minor_contributors_x_hotspot');
      expect(compound.severity, Severity.high);
      expect(compound.subject, 'lib/hot.dart');
    });

    test('stays silent without the hotspot half of the join', () {
      final findings = ownershipOn('lib/quiet.dart', minorContributors: 4);

      expect(
        correlator
            .correlate(findings)
            .where((c) => c.metric == 'minor_contributors_x_hotspot'),
        isEmpty,
      );
    });
  });

  group('Rule 8: burnout alongside active bug hotspots', () {
    test('fires High when both repo-level signals are present', () {
      final findings = [
        ...burnoutFindings(),
        ...hotspotsOn(['lib/a.dart']),
      ];

      final compound = correlator
          .correlate(findings)
          .singleWhere((c) => c.metric == 'burnout_x_bug_introduction');
      expect(compound.severity, Severity.high);
      expect(compound.subject, 'repository');
      expect(compound.evidence['active_bug_hotspots'], ['lib/a.dart']);
    });

    test('stays silent without hotspots', () {
      expect(
        correlator
            .correlate(burnoutFindings())
            .where((c) => c.metric == 'burnout_x_bug_introduction'),
        isEmpty,
      );
    });
  });

  group('Bird minor-contributor classifier finding', () {
    test('3+ minor contributors band Elevated with a sample in evidence', () {
      final finding = ownershipOn(
        'lib/x.dart',
        minorContributors: 3,
      ).singleWhere((f) => f.metric == 'minor_contributor_count');

      expect(finding.severity, Severity.elevated);
      expect(finding.value, 3);
      expect(finding.evidence['minor_contributor_count'], 3);
    });

    test('fewer than 3 minor contributors stay silent', () {
      expect(
        ownershipOn(
          'lib/x.dart',
          minorContributors: 2,
        ).where((f) => f.metric == 'minor_contributor_count'),
        isEmpty,
      );
    });
  });
}
