import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

void main() {
  const fc = FindingClassifier();

  group('Severity', () {
    test('ranks ascend with severity and max picks the higher', () {
      expect(Severity.critical.rank, greaterThan(Severity.high.rank));
      expect(Severity.high.rank, greaterThan(Severity.elevated.rank));
      expect(Severity.max(Severity.low, Severity.critical), Severity.critical);
      expect(Severity.max(Severity.high, Severity.moderate), Severity.high);
    });

    test('isMaterial excludes healthy/normal/info/low', () {
      expect(Severity.critical.isMaterial, isTrue);
      expect(Severity.elevated.isMaterial, isTrue);
      expect(Severity.low.isMaterial, isFalse);
      expect(Severity.healthy.isMaterial, isFalse);
      expect(Severity.info.isMaterial, isFalse);
    });
  });

  group('RepoStats', () {
    test('percentile handles empty and single values', () {
      expect(RepoStats.percentile(const [], 0.5), 0.0);
      expect(RepoStats.percentile(const [7], 0.9), 7.0);
    });

    test('median, quartiles, iqr, and clamping', () {
      expect(RepoStats.median(const [1, 2, 3, 4]), 2.5);
      final (q1, q3) = RepoStats.quartiles(const [1, 2, 3, 4, 5]);
      expect(q1, 2.0);
      expect(q3, 4.0);
      expect(RepoStats.iqr(const [1, 2, 3, 4, 5]), 2.0);
      // p out of range clamps.
      expect(RepoStats.percentile(const [1, 2, 3], 2.0), 3.0);
      expect(RepoStats.percentile(const [1, 2, 3], -1.0), 1.0);
    });

    test('topDecileThreshold', () {
      expect(
          RepoStats.topDecileThreshold(const [1, 1, 1, 10]), greaterThan(1.0));
    });
  });

  group('PathKey', () {
    test('normalize strips diff prefixes, ./ and leading slashes', () {
      expect(PathKey.normalize('a/lib/x.dart'), 'lib/x.dart');
      expect(PathKey.normalize('b/lib/x.dart'), 'lib/x.dart');
      expect(PathKey.normalize('./lib/x.dart'), 'lib/x.dart');
      expect(PathKey.normalize('/lib/x.dart'), 'lib/x.dart');
      expect(PathKey.normalize(r'lib\x.dart'), 'lib/x.dart');
    });

    test('topDir returns first segment or empty', () {
      expect(PathKey.topDir('lib/src/x.dart'), 'lib');
      expect(PathKey.topDir('x.dart'), '');
    });
  });

  group('BusFactorClassifier', () {
    BusFactorDto dto(double topPct) => BusFactorDto(
          busFactor: 1,
          totalDevelopers: 3,
          topContributors: [
            DeveloperContribution(
                author: 'A', contributions: 10, percentage: topPct),
          ],
        );

    test('bands', () {
      expect(fc.fromBusFactor(dto(0.7)).single.severity, Severity.critical);
      expect(fc.fromBusFactor(dto(0.4)).single.severity, Severity.moderate);
      expect(fc.fromBusFactor(dto(0.1)).single.severity, Severity.healthy);
    });

    test('empty contributors yields nothing', () {
      expect(
        fc.fromBusFactor(BusFactorDto(
            busFactor: 0, totalDevelopers: 0, topContributors: [])),
        isEmpty,
      );
    });
  });

  group('OwnershipClassifier', () {
    ChurnMetricsWithAuthorsDto dto(Map<String, int> authors) =>
        ChurnMetricsWithAuthorsDto(
          fileChurn: {
            'lib/x.dart': ContributionStats(
                total: authors.values.fold(0, (a, b) => a + b),
                authors: authors)
          },
          classChurn: const {},
          blockChurn: const {},
          totalCommits: 10,
        );

    test('critical, moderate, and skipped bands', () {
      expect(fc.fromOwnership(dto({'A': 9, 'B': 1})).single.severity,
          Severity.critical);
      expect(fc.fromOwnership(dto({'A': 4, 'B': 3, 'C': 3})).single.severity,
          Severity.moderate);
      expect(fc.fromOwnership(dto({'A': 2, 'B': 2, 'C': 2, 'D': 2, 'E': 2})),
          isEmpty);
    });

    test('empty stats skipped', () {
      final empty = const ChurnMetricsWithAuthorsDto(
        fileChurn: {'x': ContributionStats(total: 0, authors: {})},
        classChurn: {},
        blockChurn: {},
        totalCommits: 0,
      );
      expect(fc.fromOwnership(empty), isEmpty);
    });
  });

  group('BugHotspotClassifier', () {
    test('time and count bands', () {
      final dto = BugHotspotDto(
        fileHotspots: {'crit': 1, 'elev': 1, 'hot': 5},
        authorHotspots: const {},
        totalFixCommitsAnalyzed: 7,
        globalAverageTimeToFixInHours: 10,
        fileAverageTimeToFixInHours: {'crit': 100, 'elev': 15},
        authorAverageTimeToFixInHours: const {},
      );
      final byFile = {for (final f in fc.fromBugHotspots(dto)) f.subject: f};
      expect(byFile['crit']!.severity, Severity.critical);
      expect(byFile['elev']!.severity, Severity.elevated);
      expect(byFile['hot']!.severity, Severity.high);
      expect(byFile['hot']!.metric, 'bug_introductions');
    });
  });

  group('ComplexityClassifier', () {
    test('high and elevated vs repo median, else skip', () {
      final dto = AdvancedCodeQualityDto(
        fileComplexity: {
          'f1': 10,
          'f2': 10,
          'f3': 10,
          'f4': 10,
          'big': 30,
          'mid': 15
        },
        coChangeMatrix: const {},
        methodChurn: const {},
        architectureDistribution: const {},
      );
      final byFile = {for (final f in fc.fromComplexity(dto)) f.subject: f};
      expect(byFile['big']!.severity, Severity.high);
      expect(byFile['mid']!.severity, Severity.elevated);
      expect(byFile.containsKey('f1'), isFalse);
    });

    test('empty or zero-median yields nothing', () {
      expect(
        fc.fromComplexity(AdvancedCodeQualityDto(
          fileComplexity: const {},
          coChangeMatrix: const {},
          methodChurn: const {},
          architectureDistribution: const {},
        )),
        isEmpty,
      );
    });
  });

  group('ChurnClassifier', () {
    test('flags top-decile churn only', () {
      final dto = const ChurnMetricsDto(
        fileChurn: {'hot': 10, 'c1': 1, 'c2': 1, 'c3': 1},
        classChurn: {},
        blockChurn: {},
        totalCommits: 13,
      );
      final findings = fc.fromChurn(dto);
      expect(findings.single.subject, 'hot');
      expect(findings.single.severity, Severity.elevated);
    });
  });

  group('LogicalCouplingClassifier', () {
    test('strong, moderate, skip and cross-module flag', () {
      final findings = fc.fromLogicalCoupling([
        LogicalCouplingDto(
            fileA: 'lib/a.dart',
            fileB: 'test/b.dart',
            coChangeCount: 9,
            confidence: 0.8),
        LogicalCouplingDto(
            fileA: 'lib/a.dart',
            fileB: 'lib/c.dart',
            coChangeCount: 4,
            confidence: 0.4),
        LogicalCouplingDto(
            fileA: 'lib/a.dart',
            fileB: 'lib/d.dart',
            coChangeCount: 1,
            confidence: 0.1),
      ]);
      expect(findings.length, 2);
      expect(findings[0].severity, Severity.high);
      expect(findings[0].evidence['cross_module'], isTrue);
      expect(findings[1].severity, Severity.moderate);
      expect(findings[1].evidence['cross_module'], isFalse);
    });
  });

  group('VolatilityClassifier', () {
    test('flags top-decile volatility', () {
      final findings = fc.fromVolatility([
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
      ]);
      expect(findings.single.subject, 'lib/hot.dart');
    });
  });

  group('DependencyClassifier', () {
    test('freshness bands', () {
      final findings = fc.fromDependencyFreshness([
        const FreshnessResult(
            name: 'p1',
            declaredVersion: '1.0.0',
            classification: 'major_behind'),
        const FreshnessResult(
            name: 'p2',
            declaredVersion: '1.0.0',
            classification: 'minor_behind'),
        const FreshnessResult(
            name: 'p3',
            declaredVersion: '1.0.0',
            classification: 'patch_behind'),
        const FreshnessResult(
            name: 'p4', declaredVersion: '1.0.0', classification: 'current'),
      ]);
      final byName = {for (final f in findings) f.subject: f.severity};
      expect(byName['p1'], Severity.critical);
      expect(byName['p2'], Severity.moderate);
      expect(byName['p3'], Severity.low);
      expect(byName.containsKey('p4'), isFalse);
    });
  });

  group('ComplianceClassifier', () {
    test('per-violation findings', () {
      const v = ComplianceViolation(
          hash: 'abc', author: 'A', email: 'a@x', message: 'm', date: 'd');
      final findings = fc.fromCompliance(const ComplianceReportDto(
        totalCommitsScanned: 20,
        unsignedCommits: [v],
        emptyMessageCommits: [v],
        unrecognizedAuthorCommits: [],
        nonConventionalCommits: [],
      ));
      final byMetric = {for (final f in findings) f.metric: f.severity};
      expect(byMetric['unsigned_commits'], Severity.moderate);
      expect(byMetric['empty_message_commits'], Severity.low);
      expect(byMetric.containsKey('non_conventional_commits'), isFalse);
    });
  });

  group('SecretsClassifier', () {
    test('parses file path and is always critical', () {
      final findings = fc.fromSecrets([
        'Commit: abc - A (d): m\nFile: lib/config.dart\nFound Potential Secret (Regex): aaa***bbb',
        'no file line here',
      ]);
      expect(findings[0].severity, Severity.critical);
      expect(findings[0].subject, 'lib/config.dart');
      expect(findings[1].subject, 'unknown');
    });
  });

  group('CompoundFindingCorrelator', () {
    const correlator = CompoundFindingCorrelator();

    test('rule 1: bug hotspot + single-owner file', () {
      final findings = [
        ...fc.fromBugHotspots(BugHotspotDto(
          fileHotspots: {'lib/x.dart': 5},
          authorHotspots: const {},
          totalFixCommitsAnalyzed: 5,
          globalAverageTimeToFixInHours: 10,
          fileAverageTimeToFixInHours: {'lib/x.dart': 100},
          authorAverageTimeToFixInHours: const {},
        )),
        ...fc.fromOwnership(const ChurnMetricsWithAuthorsDto(
          fileChurn: {
            'lib/x.dart': ContributionStats(total: 10, authors: {'A': 10})
          },
          classChurn: {},
          blockChurn: {},
          totalCommits: 10,
        )),
      ];
      final compounds = correlator.correlate(findings);
      expect(compounds.any((c) => c.metric == 'bug_hotspot_x_single_owner'),
          isTrue);
      expect(compounds.first.category, 'compound');
      expect(compounds.first.severity, Severity.critical);
    });

    test('rule 2: complexity outlier + churn', () {
      final findings = [
        ...fc.fromComplexity(AdvancedCodeQualityDto(
          fileComplexity: {'lib/x.dart': 30, 'a': 10, 'b': 10, 'c': 10},
          coChangeMatrix: const {},
          methodChurn: const {},
          architectureDistribution: const {},
        )),
        ...fc.fromChurn(const ChurnMetricsDto(
          fileChurn: {'lib/x.dart': 10, 'a': 1, 'b': 1, 'c': 1},
          classChurn: {},
          blockChurn: {},
          totalCommits: 13,
        )),
      ];
      final compounds = correlator.correlate(findings);
      expect(compounds.any((c) => c.metric == 'complexity_x_churn'), isTrue);
    });

    test('rule 3: strong cross-module coupling', () {
      final findings = fc.fromLogicalCoupling([
        LogicalCouplingDto(
            fileA: 'lib/a.dart',
            fileB: 'app/b.dart',
            coChangeCount: 9,
            confidence: 0.9),
      ]);
      final compounds = correlator.correlate(findings);
      expect(compounds.single.metric, 'cross_module_coupling');
      expect(compounds.single.severity, Severity.high);
    });

    test('rule 4: stale dependency + secret in config', () {
      final findings = [
        ...fc.fromDependencyFreshness([
          const FreshnessResult(
              name: 'p',
              declaredVersion: '1.0.0',
              classification: 'major_behind'),
        ]),
        ...fc.fromSecrets([
          'Commit: x\nFile: pubspec.yaml\nFound Potential Secret (Regex): a***b',
        ]),
      ];
      final compounds = correlator.correlate(findings);
      expect(compounds.any((c) => c.metric == 'stale_dependency_x_secret'),
          isTrue);
    });

    test('no compound when subjects differ', () {
      final findings = [
        ...fc.fromComplexity(AdvancedCodeQualityDto(
          fileComplexity: {'lib/x.dart': 30, 'a': 10, 'b': 10, 'c': 10},
          coChangeMatrix: const {},
          methodChurn: const {},
          architectureDistribution: const {},
        )),
        ...fc.fromChurn(const ChurnMetricsDto(
          fileChurn: {'lib/other.dart': 10, 'a': 1, 'b': 1, 'c': 1},
          classChurn: {},
          blockChurn: {},
          totalCommits: 13,
        )),
      ];
      expect(correlator.correlate(findings), isEmpty);
    });
  });

  group('ReportPayload', () {
    test('ranks, dedupes compounds from top, counts summary', () {
      final singleton = const Finding(
        category: 'complexity',
        source: 's',
        severity: Severity.high,
        subject: 'lib/x.dart',
        metric: 'file_complexity',
        value: 30,
        band: 'b',
        message: 'm',
      );
      final compound = const Finding(
        category: 'compound',
        source: 's',
        severity: Severity.critical,
        subject: 'lib/x.dart',
        metric: 'complexity_x_churn',
        value: 1,
        band: 'b',
        message: 'm',
      );
      final payload = ReportPayload.fromFindings(
        reportType: 'technical',
        findings: [singleton],
        compounds: [compound],
      );
      // Compounds live in their own list, not duplicated inside top_findings.
      expect(payload.compoundFindings.single.metric, 'complexity_x_churn');
      expect(
          payload.topFindings.every((f) => f.category != 'compound'), isTrue);
      expect(payload.summaryBySeverity['Critical'], 1);
      expect(payload.summaryBySeverity['High'], 1);

      final json = payload.toJson();
      expect(json['report_type'], 'technical');
      expect(json['top_findings'], isA<List>());
      expect(json['guidance'], contains('already classified'));
    });

    test('bounds the number of findings', () {
      final many = List.generate(
        20,
        (i) => Finding(
          category: 'complexity',
          source: 's',
          severity: Severity.high,
          subject: 'f$i',
          metric: 'm',
          value: i,
          band: 'b',
          message: 'm',
        ),
      );
      final payload = ReportPayload.fromFindings(
        reportType: 't',
        findings: many,
        compounds: const [],
        maxTopFindings: 5,
      );
      expect(payload.topFindings.length, 5);
    });
  });
}
