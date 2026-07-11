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
          sources: const [
            AnalysisType.bugHotspots,
            AnalysisType.fileOwnership,
            AnalysisType.compound
          ],
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
          sources: const [AnalysisType.codeQuality, AnalysisType.compound],
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
          sources: const [AnalysisType.logicalCoupling, AnalysisType.compound],
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
            sources: const [
              AnalysisType.detectSecrets,
              AnalysisType.dependencyDrift,
              AnalysisType.compound,
            ],
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
          sources: const [
            AnalysisType.universalLexicalMetrics,
            AnalysisType.codeQuality,
            AnalysisType.compound,
          ],
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
        sources: const [
          AnalysisType.fileOwnership,
          AnalysisType.bugHotspots,
          AnalysisType.compound
        ],
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
          sources: const [
            AnalysisType.fileOwnership,
            AnalysisType.bugHotspots,
            AnalysisType.compound
          ],
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
        sources: const [
          AnalysisType.commitVelocity,
          AnalysisType.bugHotspots,
          AnalysisType.compound
        ],
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
    required List<AnalysisType> sources,
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
