import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

/// Every classified finding must carry its academic grounding: a compact
/// `basis` citation tag (inline in every report preview, so it is
/// token-bounded) and a fuller `rationale` (offloaded full report only).
/// These tests encode the business rule that rw_git's intelligence is
/// research-backed and that the research is visible in the payload, not
/// just in the documentation.
void main() {
  const fc = FindingClassifier();

  /// The recurring inline token budget per finding: a basis longer than this
  /// erodes the preview savings it rides on.
  const int maximumBasisLengthInCharacters = 120;

  final citationYearPattern = RegExp(r'\b(19|20)\d{2}\b');

  void expectResearchBacked(List<Finding> findings, String classifierLabel) {
    expect(findings, isNotEmpty, reason: '$classifierLabel produced nothing');
    for (final finding in findings) {
      expect(finding.basis, isNotNull,
          reason: '$classifierLabel finding lacks a basis');
      expect(finding.basis!.length,
          lessThanOrEqualTo(maximumBasisLengthInCharacters),
          reason: '$classifierLabel basis exceeds the inline token budget');
      expect(finding.basis, matches(citationYearPattern),
          reason: '$classifierLabel basis lacks a citation year');
      expect(finding.rationale, isNotNull,
          reason: '$classifierLabel finding lacks a rationale');
      expect(finding.rationale, matches(citationYearPattern),
          reason: '$classifierLabel rationale lacks a citation year');
    }
  }

  group('every classifier emits research-backed findings', () {
    test('bus factor', () {
      expectResearchBacked(
        fc.fromBusFactor(BusFactorDto(
          busFactor: 1,
          totalDevelopers: 3,
          topContributors: [
            DeveloperContribution(
                author: 'A', contributions: 10, percentage: 0.7),
          ],
        )),
        'BusFactorClassifier',
      );
    });

    test('ownership', () {
      expectResearchBacked(
        fc.fromOwnership(const ChurnMetricsWithAuthorsDto(
          fileChurn: {
            'lib/x.dart': ContributionStats(total: 10, authors: {'A': 9})
          },
          classChurn: {},
          blockChurn: {},
          totalCommits: 10,
        )),
        'OwnershipClassifier',
      );
    });

    test('bug hotspots', () {
      expectResearchBacked(
        fc.fromBugHotspots(BugHotspotDto(
          fileHotspots: {'lib/x.dart': 5},
          authorHotspots: const {},
          totalFixCommitsAnalyzed: 5,
          globalAverageBugLifetimeInDays: 10,
          fileAverageBugLifetimeInDays: {'lib/x.dart': 100},
          authorAverageBugLifetimeInDays: const {},
        )),
        'BugHotspotClassifier',
      );
    });

    test('complexity', () {
      expectResearchBacked(
        fc.fromComplexity(AdvancedCodeQualityDto(
          fileComplexity: {'big': 30, 'a': 10, 'b': 10, 'c': 10},
          coChangeMatrix: const {},
          methodChurn: const {},
          architectureDistribution: const {},
        )),
        'ComplexityClassifier',
      );
    });

    test('churn', () {
      expectResearchBacked(
        fc.fromChurn(const ChurnMetricsDto(
          fileChurn: {'hot': 10, 'c1': 1, 'c2': 1, 'c3': 1},
          classChurn: {},
          blockChurn: {},
          totalCommits: 13,
        )),
        'ChurnClassifier',
      );
    });

    test('logical coupling', () {
      expectResearchBacked(
        fc.fromLogicalCoupling([
          LogicalCouplingDto(
              fileA: 'lib/a.dart',
              fileB: 'test/b.dart',
              coChangeCount: 9,
              confidence: 0.8),
        ]),
        'LogicalCouplingClassifier',
      );
    });

    test('volatility', () {
      expectResearchBacked(
        fc.fromVolatility([
          CodeVolatilityDto(
              filePath: 'lib/hot.dart',
              totalChanges: 40,
              uniqueAuthors: 5,
              volatilityScore: 200),
          CodeVolatilityDto(
              filePath: 'lib/a.dart',
              totalChanges: 2,
              uniqueAuthors: 1,
              volatilityScore: 2),
          CodeVolatilityDto(
              filePath: 'lib/b.dart',
              totalChanges: 2,
              uniqueAuthors: 1,
              volatilityScore: 2),
          CodeVolatilityDto(
              filePath: 'lib/c.dart',
              totalChanges: 2,
              uniqueAuthors: 1,
              volatilityScore: 2),
        ]),
        'VolatilityClassifier',
      );
    });

    test('dependency freshness', () {
      expectResearchBacked(
        fc.fromDependencyFreshness([
          const FreshnessResult(
              name: 'p1',
              declaredVersion: '1.0.0',
              classification: 'major_behind'),
        ]),
        'DependencyClassifier',
      );
    });

    test('compliance', () {
      const violation = ComplianceViolation(
          hash: 'abc', author: 'A', email: 'a@x', message: 'm', date: 'd');
      expectResearchBacked(
        fc.fromCompliance(const ComplianceReportDto(
          totalCommitsScanned: 20,
          unsignedCommits: [violation],
          emptyMessageCommits: [],
          unrecognizedAuthorCommits: [],
          nonConventionalCommits: [],
        )),
        'ComplianceClassifier',
      );
    });

    test('secrets', () {
      expectResearchBacked(
        fc.fromSecrets(['Commit: abc\nFile: lib/config.dart\nFound: x***y']),
        'SecretsClassifier',
      );
    });

    test('compound findings carry a per-rule basis', () {
      const correlator = CompoundFindingCorrelator();
      final compounds = correlator.correlate([
        ...fc.fromBugHotspots(BugHotspotDto(
          fileHotspots: {'lib/x.dart': 5},
          authorHotspots: const {},
          totalFixCommitsAnalyzed: 5,
          globalAverageBugLifetimeInDays: 10,
          fileAverageBugLifetimeInDays: {'lib/x.dart': 100},
          authorAverageBugLifetimeInDays: const {},
        )),
        ...fc.fromOwnership(const ChurnMetricsWithAuthorsDto(
          fileChurn: {
            'lib/x.dart': ContributionStats(total: 10, authors: {'A': 10})
          },
          classChurn: {},
          blockChurn: {},
          totalCommits: 10,
        )),
      ]);
      expectResearchBacked(compounds, 'CompoundFindingCorrelator');
    });
  });

  group('Finding serialization of basis/rationale', () {
    const bare = Finding(
      category: 'churn',
      source: 'analyze_code_quality',
      severity: Severity.elevated,
      subject: 'lib/x.dart',
      metric: 'file_churn',
      value: 5,
      band: 'top-decile',
      message: 'm',
    );

    test('toJson omits basis/rationale when unset', () {
      final json = bare.toJson();
      expect(json.containsKey('basis'), isFalse);
      expect(json.containsKey('rationale'), isFalse);
    });

    test('toJson includes basis/rationale when set, copyWith preserves them',
        () {
      final backed = bare.copyWith(
          basis: 'Churn (Nagappan & Ball 2005)',
          rationale: 'Churn predicts defects (Nagappan & Ball, ICSE 2005).');
      final json = backed.copyWith(severity: Severity.high).toJson();
      expect(json['basis'], 'Churn (Nagappan & Ball 2005)');
      expect(json['rationale'], contains('ICSE 2005'));
    });
  });
}
