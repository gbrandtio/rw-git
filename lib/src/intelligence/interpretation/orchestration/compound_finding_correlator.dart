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

import 'package:rw_git/src/constants.dart';

import '../models/analysis_type.dart';
import '../models/finding.dart';
import '../models/severity.dart';

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

  /// Rule 4 — exposed secret alongside stale dependencies.
  static const String staleDependencySecretBasis =
      'Secret leakage x supply chain (Meli et al. 2019; Ohm et al. 2020)';
  static const String staleDependencySecretRationale =
      'A credential in a dependency manifest or config (Meli et al., USENIX '
      'Security 2019) combined with major-version-stale dependencies '
      'widens the supply-chain attack surface (Ohm et al., DIMVA 2020).';

  /// Rule 6 — author-level knowledge-loss risk.
  static const String knowledgeLossBasis =
      'Truck factor x hotspots (Avelino 2016; Fritz 2010; Mockus 2002)';
  static const String knowledgeLossRationale =
      'When one author solely owns several bug-hotspot files at once, their '
      'departure orphans the buggiest code in the repository — truck-factor '
      'analysis (Avelino et al. 2016), degree-of-knowledge modelling (Fritz '
      'et al. 2010), and expertise studies (Mockus & Herbsleb 2002) all '
      'identify this as the costliest knowledge to lose.';

  /// Rule 7 — many minor contributors on a bug hotspot.
  static const String minorContributorsHotspotBasis =
      'Minor contributors x hotspot (Bird et al. 2011; Śliwerski 2005)';
  static const String minorContributorsHotspotRationale =
      'Bird et al. (FSE 2011) found minor-contributor count the strongest '
      'ownership-structure defect predictor; on a file SZZ already marks a '
      'bug hotspot, continued shallow edits compound the injection risk.';

  /// Rule 8 — sustained burnout-window work alongside active bug hotspots.
  static const String burnoutBugIntroductionBasis =
      'Burnout x bug introduction (Claes et al. 2018; Eyolfson et al. 2011)';
  static const String burnoutBugIntroductionRationale =
      'Sustained nights-and-weekends work is the historical signature of '
      'crunch (Claes, Mens & Grosjean, ICSE 2018), and commits written in '
      'off-hours are measurably buggier (Eyolfson, Tan & Lam, MSR 2011). '
      'When the repository simultaneously shows active bug hotspots, the '
      'delivery-health problem and the defect problem reinforce each other.';

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
          sources: const [AnalysisType.bugHotspots, AnalysisType.fileOwnership],
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
          sources: const [AnalysisType.codeQuality],
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
          sources: const [AnalysisType.logicalCoupling],
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
              AnalysisType.detectSecrets,
              AnalysisType.dependencyDrift,
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
            AnalysisType.universalLexicalMetrics,
            AnalysisType.codeQuality,
          ],
          basis: realComplexityChurnBasis,
          rationale: realComplexityChurnRationale,
          evidence: {'lexical_complexity': _ref(lexical), 'churn': _ref(churn)},
        ));
      }
    }

    // Rule 6: one author solely owning several bug-hotspot files → author-
    // level knowledge-loss risk (the aggregate view Rule 1 gives per file).
    final hotspotFilesByOwner = <String, List<String>>{};
    for (final owner in of('ownership')) {
      if (owner.metric != 'single_author_ownership') continue;
      if (owner.severity.rank < Severity.critical.rank) continue;
      if (onSubject('bugHotspot', owner.subject) == null) continue;
      final author = owner.evidence['top_author'];
      if (author is! String) continue;
      hotspotFilesByOwner.putIfAbsent(author, () => []).add(owner.subject);
    }
    for (final entry in hotspotFilesByOwner.entries) {
      if (entry.value.length < knowledgeLossMinimumFiles) continue;
      final files = entry.value..sort();
      compounds.add(_compound(
        subject: entry.key,
        metric: 'knowledge_loss_risk',
        band: '>= $knowledgeLossMinimumFiles single-owner bug hotspots',
        message: 'Knowledge-loss risk: if ${entry.key} leaves, '
            '${files.length} bug-hotspot files they almost solely own go '
            'dark: ${files.join(', ')}.',
        sources: const [AnalysisType.fileOwnership, AnalysisType.bugHotspots],
        basis: knowledgeLossBasis,
        rationale: knowledgeLossRationale,
        evidence: {'author': entry.key, 'at_risk_files': files},
      ));
    }

    // Rule 7: many minor contributors on a file SZZ marks a bug hotspot →
    // Bird's strongest ownership-structure defect signal, compounded.
    for (final owner in of('ownership')) {
      if (owner.metric != 'minor_contributor_count') continue;
      final hotspot = onSubject('bugHotspot', owner.subject);
      if (hotspot != null) {
        compounds.add(_compound(
          subject: owner.subject,
          metric: 'minor_contributors_x_hotspot',
          band: 'many minor contributors on a bug hotspot',
          message: 'Defect-proneness risk: ${owner.subject} is a bug hotspot '
              'edited by ${owner.evidence['minor_contributor_count']} minor '
              'contributors, each without deep context.',
          sources: const [AnalysisType.fileOwnership, AnalysisType.bugHotspots],
          basis: minorContributorsHotspotBasis,
          rationale: minorContributorsHotspotRationale,
          evidence: {'ownership': _ref(owner), 'bug_hotspot': _ref(hotspot)},
          severity: Severity.high,
        ));
      }
    }

    // Rule 8: sustained burnout-window work (High) co-occurring with active
    // bug hotspots → the delivery-health and defect problems reinforce each
    // other. Repo-level co-occurrence, deliberately not a per-commit causal
    // attribution (SZZ dates are UTC-normalized; burnout is wall-clock).
    final burnout = of('velocity')
        .where((v) =>
            v.metric == 'burnout_commit_share' &&
            v.severity.rank >= Severity.high.rank)
        .toList();
    final activeHotspots = of('bugHotspot')
        .where((h) => h.severity.rank >= Severity.elevated.rank)
        .toList();
    if (burnout.isNotEmpty && activeHotspots.isNotEmpty) {
      compounds.add(_compound(
        subject: 'repository',
        metric: 'burnout_x_bug_introduction',
        band: 'sustained off-hours work alongside active bug hotspots',
        message: 'Compounding risk: over the analyzed window the team works '
            'heavily outside regular hours while '
            '${activeHotspots.length} bug hotspot(s) are active — off-hours '
            'commits are measurably buggier.',
        sources: const [AnalysisType.commitVelocity, AnalysisType.bugHotspots],
        basis: burnoutBugIntroductionBasis,
        rationale: burnoutBugIntroductionRationale,
        evidence: {
          'burnout': _ref(burnout.first),
          'active_bug_hotspots': activeHotspots.map((h) => h.subject).toList(),
        },
        severity: Severity.high,
      ));
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
    required List<AnalysisType> sources,
    required String basis,
    required String rationale,
    required Map<String, dynamic> evidence,
    Severity severity = Severity.critical,
  }) {
    return Finding(
      category: 'compound',
      source: sources,
      severity: severity,
      subject: subject,
      metric: metric,
      value: sources.length,
      band: band,
      message: message,
      basis: basis,
      rationale: rationale,
      evidence: {'sources': sources.map((s) => s.name).toList(), ...evidence},
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
