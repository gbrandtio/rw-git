/// ----------------------------------------------------------------------------
/// compound_finding_correlator.dart
/// ----------------------------------------------------------------------------
/// Joins already-classified findings across tools to surface compound risks
/// that rarely appear from any single analysis. This is the multi-tool AND
/// reasoning that small models fail at, done deterministically instead.
///
/// The correlator is purely additive: it returns the new compound findings so
/// callers can merge them with the singletons and rank compound-first, without
/// ever losing a raw finding (a secret must never be hidden by a correlation).
library;

import 'finding.dart';
import 'severity.dart';

/// Correlates a flat list of findings into higher-order compound findings.
class CompoundFindingCorrelator {
  const CompoundFindingCorrelator();

  /// Rule 1 — hotspot owned by a single author.
  static const String tribalKnowledgeBasis =
      'Ownership x defect density (Bird et al. 2011; Śliwerski 2005)';
  static const String tribalKnowledgeRationale =
      'Single-owner components measurably accumulate more defects (Bird et '
      'al., FSE 2011); when SZZ attribution also marks the file a bug '
      'hotspot, the buggiest code depends on knowledge no one else holds.';

  /// Rule 2 — complexity outlier that also churns.
  static const String complexityChurnBasis =
      'Churn x complexity defect risk (Nagappan & Ball 2005; McCabe 1976)';
  static const String complexityChurnRationale =
      'Churn predicts defect density (Nagappan & Ball, ICSE 2005) and '
      'complexity multiplies the chance each change goes wrong (McCabe, '
      '1976); their intersection is the prime defect-injection site.';

  /// Rule 3 — strong coupling across declared modules.
  static const String crossModuleCouplingBasis =
      'Cross-module co-change smell (Gall et al. 1998; Garcia et al. 2009)';
  static const String crossModuleCouplingRationale =
      'Co-change coupling that crosses declared module boundaries is an '
      'architectural bad smell (Gall et al., ICSM 1998; Garcia, Oliveira & '
      'Murta, SBES 2009): the real structure has drifted from the intended '
      'one.';

  /// Rule 5 — genuine McCabe outlier that also churns.
  static const String realComplexityChurnBasis =
      'McCabe complexity x churn (McCabe 1976; Nagappan & Ball 2005)';
  static const String realComplexityChurnRationale =
      'Genuine cyclomatic complexity above the high-risk band (McCabe, '
      '1976) on a file with top-decile churn (Nagappan & Ball, ICSE 2005) '
      'is the strongest single defect-injection predictor the report can '
      'compute.';

  /// Rule 6 — predicted merge conflict on a known bug hotspot.
  static const String conflictHotspotBasis =
      'Merge conflict x bug hotspot (Brun et al. 2011; Śliwerski 2005)';
  static const String conflictHotspotRationale =
      'A predicted merge conflict (Brun et al., FSE 2011) on a file with '
      'SZZ-attributed bug density (Śliwerski et al., MSR 2005) risks '
      'resolving the conflict incorrectly in precisely the code that '
      'breeds bugs.';

  /// Rule 4 — exposed secret alongside stale dependencies.
  static const String staleDependencySecretBasis =
      'Secret leakage x supply chain (Meli et al. 2019; Ohm et al. 2020)';
  static const String staleDependencySecretRationale =
      'A credential in a dependency manifest or config (Meli et al., USENIX '
      'Security 2019) combined with major-version-stale dependencies '
      'widens the supply-chain attack surface (Ohm et al., DIMVA 2020).';

  List<Finding> correlate(List<Finding> findings) {
    final byCategory = <String, List<Finding>>{};
    for (final f in findings) {
      byCategory.putIfAbsent(f.category, () => []).add(f);
    }

    List<Finding> of(String category) => byCategory[category] ?? const [];

    Finding? onSubject(String category, String subject, {Severity? atLeast}) {
      for (final f in of(category)) {
        if (f.subject == subject &&
            (atLeast == null || f.severity.rank >= atLeast.rank)) {
          return f;
        }
      }
      return null;
    }

    final compounds = <Finding>[];

    // Rule 1: bug hotspot + single-owner (per-file bus factor Critical) on the
    // same file → undocumented tribal knowledge in the buggiest code.
    for (final hotspot in of('bugHotspot')) {
      final owner =
          onSubject('ownership', hotspot.subject, atLeast: Severity.critical);
      if (owner != null) {
        compounds.add(_compound(
          subject: hotspot.subject,
          metric: 'bug_hotspot_x_single_owner',
          band: 'bug hotspot owned by a single author',
          message: 'Tribal-knowledge risk: ${hotspot.subject} is a bug '
              'hotspot owned almost entirely by '
              '${owner.evidence['top_author']}.',
          sources: const ['analyze_bug_hotspots', 'analyze_file_ownership'],
          basis: tribalKnowledgeBasis,
          rationale: tribalKnowledgeRationale,
          evidence: {'bug_hotspot': _ref(hotspot), 'ownership': _ref(owner)},
        ));
      }
    }

    // Rule 2: complexity High outlier + high churn on the same file → the prime
    // defect-injection risk (actively-changing complex code).
    for (final cx in of('complexity')) {
      if (cx.severity.rank < Severity.high.rank) continue;
      final churn = onSubject('churn', cx.subject);
      if (churn != null) {
        compounds.add(_compound(
          subject: cx.subject,
          metric: 'complexity_x_churn',
          band: 'complex, actively-changing code',
          message: 'Prime defect-injection risk: ${cx.subject} is a complexity '
              'outlier that also churns frequently.',
          sources: const ['analyze_code_quality'],
          basis: complexityChurnBasis,
          rationale: complexityChurnRationale,
          evidence: {'complexity': _ref(cx), 'churn': _ref(churn)},
        ));
      }
    }

    // Rule 3: strong coupling spanning declared modules → architecture smell,
    // equivalent to a drift signal.
    for (final c in of('coupling')) {
      if (c.severity.rank < Severity.high.rank) continue;
      if (c.evidence['cross_module'] == true) {
        compounds.add(_compound(
          subject: c.subject,
          metric: 'cross_module_coupling',
          band: 'strong coupling across modules',
          message: 'Architecture smell: ${c.evidence['file_a']} and '
              '${c.evidence['file_b']} are strongly coupled across module '
              'boundaries.',
          sources: const ['analyze_logical_coupling'],
          basis: crossModuleCouplingBasis,
          rationale: crossModuleCouplingRationale,
          evidence: c.evidence,
          severity: Severity.high,
        ));
      }
    }

    // Rule 4: dependency major-version-behind + a secret in a manifest/config
    // file → escalate to a single Critical security finding.
    final staleDeps =
        of('dependency').where((d) => d.severity == Severity.critical).toList();
    if (staleDeps.isNotEmpty) {
      for (final secret in of('secret')) {
        if (_looksLikeDependencyConfig(secret.subject)) {
          compounds.add(_compound(
            subject: secret.subject,
            metric: 'stale_dependency_x_secret',
            band: 'exposed secret alongside outdated dependencies',
            message: 'Escalated security risk: a secret is exposed in '
                '${secret.subject} while ${staleDeps.length} dependency(ies) '
                'are a major version behind.',
            sources: const [
              'detect_secrets_in_commits',
              'analyze_dependency_drift',
            ],
            basis: staleDependencySecretBasis,
            rationale: staleDependencySecretRationale,
            evidence: {
              'secret': _ref(secret),
              'stale_dependencies': staleDeps.map((d) => d.subject).toList(),
            },
          ));
        }
      }
    }

    // Rule 5: a genuine McCabe cyclomatic-complexity outlier (absolute bands,
    // unlike the keyword-count proxy of Rule 2) that also churns heavily.
    for (final lexical in of('lexicalComplexity')) {
      if (lexical.severity.rank < Severity.high.rank) continue;
      final churn = onSubject('churn', lexical.subject);
      if (churn != null) {
        compounds.add(_compound(
          subject: lexical.subject,
          metric: 'real_complexity_x_churn',
          band: 'high McCabe complexity in actively-changing code',
          message: 'Prime defect-injection risk: ${lexical.subject} has '
              'genuine McCabe complexity '
              '${lexical.evidence['cyclomatic_complexity']} and top-decile '
              'churn.',
          sources: const [
            'calculate_universal_lexical_metrics',
            'analyze_code_quality',
          ],
          basis: realComplexityChurnBasis,
          rationale: realComplexityChurnRationale,
          evidence: {'lexical_complexity': _ref(lexical), 'churn': _ref(churn)},
        ));
      }
    }

    // Rule 6: a predicted merge conflict landing on a known bug hotspot.
    for (final conflict in of('conflictRisk')) {
      final hotspot = onSubject('bugHotspot', conflict.subject);
      if (hotspot != null) {
        compounds.add(_compound(
          subject: conflict.subject,
          metric: 'conflict_x_bug_hotspot',
          band: 'merge conflict predicted on a bug hotspot',
          message: 'High-stakes merge: ${conflict.subject} is expected to '
              'conflict and is already a bug hotspot.',
          sources: const ['predict_merge_conflicts', 'analyze_bug_hotspots'],
          basis: conflictHotspotBasis,
          rationale: conflictHotspotRationale,
          evidence: {
            'conflict_risk': _ref(conflict),
            'bug_hotspot': _ref(hotspot),
          },
          severity: Severity.high,
        ));
      }
    }

    return compounds;
  }

  /// A compact reference to a contributing finding — enough to explain the
  /// compound without embedding the full finding (which would bloat the
  /// payload and push it past the inline threshold).
  Map<String, dynamic> _ref(Finding f) => {
        'subject': f.subject,
        'severity': f.severity.label,
        'band': f.band,
      };

  Finding _compound({
    required String subject,
    required String metric,
    required String band,
    required String message,
    required List<String> sources,
    required String basis,
    required String rationale,
    required Map<String, dynamic> evidence,
    Severity severity = Severity.critical,
  }) {
    return Finding(
      category: 'compound',
      source: sources.join(' + '),
      severity: severity,
      subject: subject,
      metric: metric,
      value: sources.length,
      band: band,
      message: message,
      basis: basis,
      rationale: rationale,
      evidence: {'sources': sources, ...evidence},
    );
  }

  bool _looksLikeDependencyConfig(String path) {
    final lowercasePath = path.toLowerCase();
    const manifests = [
      'pubspec.yaml',
      'package.json',
      'requirements.txt',
      'go.mod',
      'cargo.toml',
      'gemfile',
    ];
    for (final manifestName in manifests) {
      if (lowercasePath.endsWith(manifestName)) return true;
    }
    return lowercasePath.contains('.env') ||
        lowercasePath.startsWith('config/') ||
        lowercasePath.contains('/config/');
  }
}
