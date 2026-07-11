import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

/// Delivery-cadence signals for the PM report: declining trend, Gini author
/// concentration, and burnout-window share. Encodes why each matters — a PM
/// report without cadence signals misses the delivery-risk half of its job.
void main() {
  const fc = FindingClassifier();

  CommitVelocityDto dto({
    String trend = 'stable',
    double slope = 0,
    double gini = 0.2,
    int burnout = 0,
    int total = 100,
    List<TimeBucket> buckets = const [],
  }) =>
      CommitVelocityDto(
        buckets: buckets,
        totalCommits: total,
        averagePerPeriod: 10,
        trend: trend,
        anomalies: const [],
        totalBurnoutCommits: burnout,
        giniCoefficient: gini,
        velocitySlope: slope,
      );

  test('healthy cadence yields no findings', () {
    expect(fc.fromCommitVelocity(dto()), isEmpty);
  });

  test('empty history yields no findings', () {
    expect(fc.fromCommitVelocity(dto(total: 0)), isEmpty);
  });

  test('declining trend with negative slope is Elevated', () {
    final findings =
        fc.fromCommitVelocity(dto(trend: 'declining', slope: -1.5));
    expect(findings.single.severity, Severity.elevated);
    expect(findings.single.metric, 'velocity_slope');
    expect(findings.single.subject, 'repository');
  });

  test('Gini above 0.6 is High and names the top author', () {
    final findings = fc.fromCommitVelocity(dto(
      gini: 0.75,
      buckets: const [
        TimeBucket(
            period: '2026-W01',
            totalCommits: 9,
            authors: {'alice': 8, 'bob': 1},
            burnoutCommits: 0),
      ],
    ));
    expect(findings.single.severity, Severity.high);
    expect(findings.single.metric, 'gini_coefficient');
    expect(findings.single.subject, 'alice');
  });

  test('burnout share above 15% is High', () {
    final findings = fc.fromCommitVelocity(dto(burnout: 20, total: 100));
    expect(findings.single.severity, Severity.high);
    expect(findings.single.metric, 'burnout_commit_share');
    expect(findings.single.value, 0.2);
  });
}
