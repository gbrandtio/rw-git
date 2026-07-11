import 'package:rw_git/rw_git.dart';
import 'package:rw_git/src/constants.dart';
import 'package:test/test.dart';

/// The refactoring-target ranker implements Tornhill's hotspot
/// prioritization (Tornhill 2015; Ostrand, Weyuker & Bell 2004): churn
/// percentile x complexity percentile, ranked. These tests pin the scoring
/// semantics — genuine McCabe preferred over the proxy, per-population
/// percentiles, minimum-score cut-off, and the cap — so a change is a
/// deliberate ADR-0010 act.
void main() {
  const ranker = RefactoringTargetRanker();

  FileLexicalMetricsDto lexical(String path, int cc) => FileLexicalMetricsDto(
    filePath: path,
    cyclomaticComplexity: cc,
    maintainabilityIndex: 90,
    abcScore: 0,
    npathComplexity: 1,
    cognitiveComplexity: 0,
    halsteadDeliveredBugs: 0,
  );

  test('ranks hot, complex files first', () {
    final targets = ranker.rank(
      fileChurn: {'lib/hot.dart': 100, 'lib/warm.dart': 50, 'lib/cold.dart': 1},
      lexicalMetrics: [
        lexical('lib/hot.dart', 40),
        lexical('lib/warm.dart', 20),
        lexical('lib/cold.dart', 2),
      ],
    );

    expect(targets.first.filePath, 'lib/hot.dart');
    expect(targets.first.riskScore, 1.0);
    expect(targets.first.complexityMetric, 'cyclomatic_complexity');
    expect(targets.map((t) => t.filePath), isNot(contains('lib/cold.dart')));
  });

  test('falls back to the complexity proxy outside the lexical sample', () {
    final targets = ranker.rank(
      fileChurn: {'lib/a.dart': 10, 'lib/b.dart': 5},
      proxyComplexity: {'lib/a.dart': 30, 'lib/b.dart': 3},
    );

    expect(targets.first.filePath, 'lib/a.dart');
    expect(targets.first.complexityMetric, 'complexity_proxy');
  });

  test('files without any complexity signal are skipped', () {
    final targets = ranker.rank(fileChurn: {'lib/only_churn.dart': 100});
    expect(targets, isEmpty);
  });

  test('scores below the minimum are dropped', () {
    // Ten files: the coldest/simplest combinations fall under the cut-off.
    final churn = {for (var i = 1; i <= 10; i++) 'f$i.dart': i};
    final complexity = {for (var i = 1; i <= 10; i++) 'f$i.dart': i};
    final targets = ranker.rank(fileChurn: churn, proxyComplexity: complexity);

    for (final target in targets) {
      expect(
        target.riskScore,
        greaterThanOrEqualTo(refactoringTargetMinimumRiskScore),
      );
    }
  });

  test('the list is capped at maxRefactoringTargets', () {
    final churn = {for (var i = 1; i <= 20; i++) 'f$i.dart': i + 100};
    final complexity = {for (var i = 1; i <= 20; i++) 'f$i.dart': i + 100};
    final targets = ranker.rank(fileChurn: churn, proxyComplexity: complexity);

    expect(targets, hasLength(maxRefactoringTargets));
  });

  test('non-source files never rank, even via the proxy', () {
    // Prose diffs match the keyword proxy ("if", "for", "while"), so a
    // hot CHANGELOG would otherwise top the list (Tornhill hotspots are
    // defined over source files only).
    final targets = ranker.rank(
      fileChurn: {'CHANGELOG.md': 500, 'pubspec.lock': 200, 'lib/a.dart': 10},
      proxyComplexity: {
        'CHANGELOG.md': 900,
        'pubspec.lock': 100,
        'lib/a.dart': 30,
      },
    );

    expect(targets.map((t) => t.filePath), ['lib/a.dart']);
  });

  test('non-source files are excluded from the percentile populations', () {
    // With CHANGELOG.md dropped before percentiling, lib/a.dart is the
    // churn and proxy maximum of the remaining population: both
    // percentiles are 1.0, not deflated by the prose file.
    final target =
        ranker
            .rank(
              fileChurn: {
                'CHANGELOG.md': 500,
                'lib/a.dart': 10,
                'lib/b.dart': 2,
              },
              proxyComplexity: {
                'CHANGELOG.md': 900,
                'lib/a.dart': 30,
                'lib/b.dart': 3,
              },
            )
            .first;

    expect(target.filePath, 'lib/a.dart');
    expect(target.churnPercentile, 1.0);
    expect(target.complexityPercentile, 1.0);
  });

  test('churn made of only non-source files yields no targets', () {
    final targets = ranker.rank(
      fileChurn: {'CHANGELOG.md': 500},
      proxyComplexity: {'CHANGELOG.md': 900},
    );
    expect(targets, isEmpty);
  });

  test('empty churn yields no targets', () {
    expect(ranker.rank(fileChurn: const {}), isEmpty);
  });

  test('toJson exposes the rounded score and both percentiles', () {
    final target =
        ranker
            .rank(
              fileChurn: {'lib/a.dart': 10, 'lib/b.dart': 1},
              proxyComplexity: {'lib/a.dart': 10, 'lib/b.dart': 1},
            )
            .first;

    final json = target.toJson();
    expect(json['file_path'], 'lib/a.dart');
    expect(json['risk_score'], 1.0);
    expect(json['churn_percentile'], 1.0);
    expect(json['complexity_percentile'], 1.0);
    expect(json['complexity_metric'], 'complexity_proxy');
  });
}
