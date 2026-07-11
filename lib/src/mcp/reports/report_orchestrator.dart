/// ----------------------------------------------------------------------------
/// report_orchestrator.dart
/// ----------------------------------------------------------------------------
/// Runs the relevant analysis algorithms server-side, classifies their DTOs
/// into severity-banded findings, correlates them into compound findings, and
/// returns a bounded [ReportPayload]. This moves the entire interpret +
/// correlate + rank workload out of the LLM and into deterministic Dart, so a
/// small model can produce a full report from a single tool call.
///
/// Independent analyses are started eagerly and awaited afterwards, so their
/// read-only git subprocesses run concurrently; CPU-bound parsing still runs
/// in background isolates inside the individual analyses (ADR-0003).
library;

import 'dart:io';
import 'dart:isolate';

import 'package:rw_git/src/constants.dart';
import 'package:rw_git/src/core/network/http_client.dart';
import 'package:rw_git/src/core/process_runner.dart';
import 'package:rw_git/src/intelligence/architecture/architecture_drift_algorithm.dart';
import 'package:rw_git/src/intelligence/architecture/logical_coupling_algorithm.dart';
import 'package:rw_git/src/intelligence/architecture/refactoring_detection_algorithm.dart';
import 'package:rw_git/src/intelligence/history/algorithms/code_volatility_algorithm.dart';
import 'package:rw_git/src/intelligence/history/algorithms/szz_algorithm.dart';
import 'package:rw_git/src/intelligence/history/heuristics/advanced_metrics_heuristic.dart';
import 'package:rw_git/src/intelligence/history/heuristics/bug_hotspots_heuristic.dart';
import 'package:rw_git/src/intelligence/history/heuristics/churn_heuristic.dart';
import 'package:rw_git/src/intelligence/history/heuristics/commit_velocity_heuristic.dart';
import 'package:rw_git/src/intelligence/history/heuristics/mega_commits_heuristic.dart';
import 'package:rw_git/src/intelligence/history/heuristics/suspicious_commits_heuristic.dart';
import 'package:rw_git/src/intelligence/architecture/bus_factor_algorithm.dart';
import 'package:rw_git/src/intelligence/security/compliance_scanner.dart';
import 'package:rw_git/src/intelligence/security/dependency_freshness_checker.dart';
import 'package:rw_git/src/intelligence/security/dependency_manifest_parser.dart';
import 'package:rw_git/src/intelligence/security/secrets_scanner.dart';
import 'package:rw_git/src/intelligence/static_analysis/clean_code_analyzer.dart';
import 'package:rw_git/src/intelligence/static_analysis/dart/dart_ast_analyzer.dart';
import 'package:rw_git/src/intelligence/static_analysis/metrics/bounded_lexical_metrics_sampler.dart';
import 'package:rw_git/src/models/architecture_drift_dto.dart';
import 'package:rw_git/src/models/churn_metrics_dto.dart';
import 'package:rw_git/src/models/churn_metrics_with_authors_dto.dart';
import 'package:rw_git/src/models/dependency_freshness_dto.dart';
import 'package:rw_git/src/vcs/git_query.dart';

import 'package:rw_git/src/intelligence/interpretation/orchestration/compound_finding_correlator.dart';
import 'package:rw_git/src/intelligence/interpretation/models/finding.dart';
import 'package:rw_git/src/intelligence/interpretation/orchestration/finding_classifier.dart';
import 'package:rw_git/src/intelligence/interpretation/orchestration/refactoring_target_ranker.dart';
import 'package:rw_git/src/intelligence/interpretation/models/report_payload.dart';

/// The findings plus the ranked Tornhill refactoring targets a technical
/// analysis pass produces from one shared set of git data.
typedef TechnicalAnalysis = ({
  List<Finding> findings,
  List<RefactoringTarget> refactoringTargets,
});

/// Builds pre-interpreted report payloads for the report meta-tools.
class ReportOrchestrator {
  final ProcessRunner runner;

  /// Optional HTTP client used only for opt-in dependency-freshness lookups.
  final RwHttpClient? httpClient;

  const ReportOrchestrator(this.runner, {this.httpClient});

  static const _classifier = FindingClassifier();
  static const _correlator = CompoundFindingCorrelator();
  static const _ranker = RefactoringTargetRanker();

  /// Technical report: complexity, churn, ownership, bug hotspots, coupling,
  /// volatility, architecture drift, clean code, and import cycles — the
  /// code-quality/architecture surface — plus the ranked Tornhill
  /// refactoring-target list.
  Future<ReportPayload> technicalReport(
    String directory, {
    String? limit,
    String? since,
    String? until,
  }) async {
    final lim = limit ?? defaultCommitLimit;
    final technical = await _technicalFindings(
      directory,
      lim,
      since: since,
      until: until,
    );
    return ReportPayload.fromFindings(
      reportType: 'technical',
      findings: technical.findings,
      compounds: _correlator.correlate(technical.findings),
      refactoringTargets: technical.refactoringTargets,
      metadata: {
        'directory': directory,
        'commit_limit': lim,
        if (since != null) 'since': since,
        if (until != null) 'until': until,
      },
    );
  }

  /// Security report: exposed secrets, commit compliance, and (opt-in)
  /// dependency freshness.
  Future<ReportPayload> securityReport(
    String directory, {
    String? limit,
    String? since,
    String? until,
    List<String> allowedEmails = const [],
    bool checkFreshness = false,
    String? branch,
  }) async {
    final lim = limit ?? defaultCommitLimit;
    final findings = await _securityFindings(
      directory,
      lim,
      since: since,
      until: until,
      allowedEmails: allowedEmails,
      checkFreshness: checkFreshness,
      branch: branch,
    );
    return ReportPayload.fromFindings(
      reportType: 'security',
      findings: findings,
      compounds: _correlator.correlate(findings),
      metadata: {
        'directory': directory,
        'commit_limit': lim,
        if (since != null) 'since': since,
        if (until != null) 'until': until,
        'freshness_checked': checkFreshness && httpClient != null,
      },
    );
  }

  /// Project-management report: knowledge concentration (bus factor + per-file
  /// ownership incl. Bird minor-contributor structure), delivery bottlenecks
  /// (bug hotspots), and delivery cadence (velocity trend, author
  /// concentration, burnout-window work).
  Future<ReportPayload> pmReport(
    String directory, {
    String? limit,
    String? since,
    String? until,
  }) async {
    final lim = limit ?? defaultCommitLimit;
    final busFactorFuture = BusFactorAlgorithm(
      runner,
    ).execute(directory, limit: lim, since: since, until: until);
    final churnAuthorsFuture = ChurnHeuristic(runner).calculateChurnWithAuthors(
      directory,
      limit: lim,
      since: since,
      until: until,
    );
    final hotspotsFuture = SzzAlgorithm(runner)
        .execute(directory, limit: lim, since: since, until: until)
        .then((matches) => BugHotspotsHeuristic().aggregate(matches));
    final velocityFuture = CommitVelocityHeuristic(runner)
        .calculateCommitVelocity(
          directory,
          limit: lim,
          since: since,
          until: until,
        );

    final findings = <Finding>[
      ..._classifier.fromBusFactor(await busFactorFuture),
      ..._classifier.fromOwnership(await churnAuthorsFuture),
      ..._classifier.fromBugHotspots(await hotspotsFuture),
      ..._classifier.fromCommitVelocity(await velocityFuture),
    ];
    return ReportPayload.fromFindings(
      reportType: 'pm',
      findings: findings,
      compounds: _correlator.correlate(findings),
      metadata: {
        'directory': directory,
        'commit_limit': lim,
        if (since != null) 'since': since,
        if (until != null) 'until': until,
      },
    );
  }

  /// Code-review report: risk signals for code under review — exposed secrets,
  /// bug hotspots, ownership structure, clean-code heuristics, complexity
  /// outliers (both the diff proxy and the genuine lexical suite on the
  /// highest-churn files) — with refactoring-explained churn discounted, plus
  /// the ranked Tornhill refactoring-target list.
  Future<ReportPayload> codeReviewReport(
    String directory, {
    String? limit,
    String? since,
    String? until,
    String? branch,
  }) async {
    final lim = limit ?? defaultCommitLimit;
    final advancedFuture = AdvancedMetricsHeuristic(runner)
        .calculateAdvancedMetrics(
          directory,
          limit: lim,
          since: since,
          until: until,
        );
    final churnAuthorsFuture = ChurnHeuristic(runner).calculateChurnWithAuthors(
      directory,
      limit: lim,
      since: since,
      until: until,
    );
    final hotspotsFuture = SzzAlgorithm(runner)
        .execute(directory, limit: lim, since: since, until: until)
        .then((matches) => BugHotspotsHeuristic().aggregate(matches));
    final secretsFuture = SecretsScanner(runner).findSecrets(
      directory,
      limit: lim,
      since: since,
      until: until,
      branch: branch,
    );
    final refactoringsFuture = RefactoringDetectionAlgorithm(
      runner,
    ).execute(directory, limit: lim, since: since, until: until);

    final advanced = await advancedFuture;
    final churnAuthors = await churnAuthorsFuture;
    final churn = _churnFromAuthors(churnAuthors);
    // One bounded top-churn sample feeds both the genuine lexical suite
    // and the clean-code heuristics on the code under review.
    const sampler = BoundedLexicalMetricsSampler();
    final topChurnSources = await sampler.readTopChurnSources(
      directory,
      churn.fileChurn,
    );
    final lexicalMetrics = await sampler.lexSources(topChurnSources);
    final cleanCode = await const CleanCodeAnalyzer().analyzeSources(
      topChurnSources,
    );
    final refactorings = await refactoringsFuture;

    final findings = <Finding>[
      ..._classifier.fromSecrets(await secretsFuture),
      ..._classifier.fromComplexity(advanced),
      ..._classifier.fromLexicalMetrics(lexicalMetrics),
      ..._classifier.fromCleanCode(cleanCode),
      ..._classifier.fromOwnership(churnAuthors),
      ..._classifier.fromBugHotspots(await hotspotsFuture),
      ..._classifier.fromChurn(churn),
    ];
    // Refactoring-aware pass (RA-SZZ insight): churn findings on files the
    // refactorings renamed are downgraded one band, exactly as in the
    // technical report — a review must not flag paid-down debt as risk.
    final contextualized = _classifier.applyRefactoringContext(
      findings,
      refactorings,
    );
    return ReportPayload.fromFindings(
      reportType: 'code_review',
      findings: contextualized,
      compounds: _correlator.correlate(contextualized),
      refactoringTargets: _ranker.rank(
        fileChurn: churn.fileChurn,
        proxyComplexity: advanced.fileComplexity,
        lexicalMetrics: lexicalMetrics,
      ),
      metadata: {
        'directory': directory,
        'commit_limit': lim,
        if (since != null) 'since': since,
        if (until != null) 'until': until,
      },
    );
  }

  /// High-level deep audit: the union of technical + security + delivery
  /// signals in one pass, which is where cross-tool compound findings are
  /// most likely to surface.
  Future<ReportPayload> repositoryAudit(
    String directory, {
    String? limit,
    String? since,
    String? until,
    List<String> allowedEmails = const [],
    bool checkFreshness = false,
    String? branch,
  }) async {
    final lim = limit ?? defaultCommitLimit;
    final busFactorFuture = BusFactorAlgorithm(
      runner,
    ).execute(directory, limit: lim, since: since, until: until);
    final megaCommitsFuture = MegaCommitsHeuristic(
      runner,
    ).findMegaCommits(directory, limit: lim, since: since, until: until);
    final suspiciousCommitsFuture = SuspiciousCommitsHeuristic(
      runner,
    ).findSuspiciousCommits(directory, limit: lim, since: since, until: until);
    final velocityFuture = CommitVelocityHeuristic(runner)
        .calculateCommitVelocity(
          directory,
          limit: lim,
          since: since,
          until: until,
        );
    final securityFuture = _securityFindings(
      directory,
      lim,
      since: since,
      until: until,
      allowedEmails: allowedEmails,
      checkFreshness: checkFreshness,
      branch: branch,
    );

    final technical = await _technicalFindings(
      directory,
      lim,
      since: since,
      until: until,
    );
    final findings = <Finding>[
      ..._classifier.fromBusFactor(await busFactorFuture),
      ..._classifier.fromMegaCommits(await megaCommitsFuture),
      ..._classifier.fromSuspiciousCommits(await suspiciousCommitsFuture),
      ..._classifier.fromCommitVelocity(await velocityFuture),
      ...technical.findings,
      ...await securityFuture,
    ];
    return ReportPayload.fromFindings(
      reportType: 'repository_audit',
      findings: findings,
      compounds: _correlator.correlate(findings),
      refactoringTargets: technical.refactoringTargets,
      maxTopFindings: 12,
      maxCompoundFindings: 8,
      metadata: {
        'directory': directory,
        'commit_limit': lim,
        if (since != null) 'since': since,
        if (until != null) 'until': until,
      },
    );
  }

  Future<TechnicalAnalysis> _technicalFindings(
    String directory,
    String lim, {
    String? since,
    String? until,
  }) async {
    final advancedFuture = AdvancedMetricsHeuristic(runner)
        .calculateAdvancedMetrics(
          directory,
          limit: lim,
          since: since,
          until: until,
        );
    final churnAuthorsFuture = ChurnHeuristic(runner).calculateChurnWithAuthors(
      directory,
      limit: lim,
      since: since,
      until: until,
    );
    final hotspotsFuture = SzzAlgorithm(runner)
        .execute(directory, limit: lim, since: since, until: until)
        .then((matches) => BugHotspotsHeuristic().aggregate(matches));
    final couplingFuture = LogicalCouplingAlgorithm(
      runner,
    ).execute(directory, limit: lim, since: since, until: until);
    final volatilityFuture = CodeVolatilityAlgorithm(
      runner,
    ).execute(directory, limit: lim, since: since, until: until);
    final refactoringsFuture = RefactoringDetectionAlgorithm(
      runner,
    ).execute(directory, limit: lim, since: since, until: until);

    // One churn computation serves both the churn and ownership classifiers
    // (the per-author breakdown carries the plain totals), and its file list
    // seeds every bounded sample below — no duplicate git passes.
    final churnAuthors = await churnAuthorsFuture;
    final churn = _churnFromAuthors(churnAuthors);

    // One bounded top-churn sample (ADR-0014) feeds the genuine lexical
    // suite, the clean-code heuristics, and Dart import-cycle detection —
    // no extra git calls, only N bounded file reads shared by all three.
    const sampler = BoundedLexicalMetricsSampler();
    final topChurnSources = await sampler.readTopChurnSources(
      directory,
      churn.fileChurn,
    );
    final lexicalMetrics = await sampler.lexSources(topChurnSources);
    final cleanCode = await const CleanCodeAnalyzer().analyzeSources(
      topChurnSources,
    );
    final importCycles = await _detectImportCycles(directory, topChurnSources);

    // Architecture drift over layers inferred from the churned file paths:
    // no extra file-system walk, and single-layer repositories are skipped
    // (no boundaries to violate).
    final inferredLayers = ArchitectureDriftAlgorithm.inferLayerPatterns(
      churn.fileChurn.keys,
    );
    final drift = inferredLayers.isEmpty
        ? const ArchitectureDriftDto.empty()
        : await ArchitectureDriftAlgorithm(ReadOnlyGitQuery(runner)).execute(
            directory,
            inferredLayers,
            limit: lim,
            since: since,
            until: until,
          );

    final advanced = await advancedFuture;
    final refactorings = await refactoringsFuture;
    final findings = <Finding>[
      ..._classifier.fromComplexity(advanced),
      ..._classifier.fromLexicalMetrics(lexicalMetrics),
      ..._classifier.fromChurn(churn),
      ..._classifier.fromOwnership(churnAuthors),
      ..._classifier.fromBugHotspots(await hotspotsFuture),
      ..._classifier.fromLogicalCoupling(await couplingFuture),
      ..._classifier.fromVolatility(await volatilityFuture),
      ..._classifier.fromRefactoringActivity(refactorings),
      ..._classifier.fromArchitectureDrift(drift),
      ..._classifier.fromCleanCode(cleanCode),
      ..._classifier.fromImportCycles(importCycles),
    ];
    // Refactoring-aware pass (RA-SZZ insight): churn/volatility findings on
    // files the refactorings renamed are downgraded one band.
    return (
      findings: _classifier.applyRefactoringContext(findings, refactorings),
      refactoringTargets: _ranker.rank(
        fileChurn: churn.fileChurn,
        proxyComplexity: advanced.fileComplexity,
        lexicalMetrics: lexicalMetrics,
      ),
    );
  }

  ChurnMetricsDto _churnFromAuthors(ChurnMetricsWithAuthorsDto withAuthors) {
    Map<String, int> totals(Map<String, ContributionStats> stats) =>
        stats.map((key, value) => MapEntry(key, value.total));
    return ChurnMetricsDto(
      fileChurn: totals(withAuthors.fileChurn),
      totalCommits: withAuthors.totalCommits,
    );
  }

  /// Detects import cycles among the Dart files of the bounded top-churn
  /// sample. Gated on the repository being a Dart project (pubspec.yaml
  /// present): on any other stack this is a structural zero-finding, not an
  /// error. Parsing runs off the main isolate (ADR-0003).
  Future<List<List<String>>> _detectImportCycles(
    String directory,
    Map<String, String> topChurnSources,
  ) async {
    final pubspec = File('$directory/pubspec.yaml');
    if (!await pubspec.exists()) return const [];

    final dartSources = {
      for (final entry in topChurnSources.entries)
        if (entry.key.endsWith('.dart')) entry.key: entry.value,
    };
    if (dartSources.isEmpty) return const [];

    // The package name rewrites same-package `package:` imports onto
    // repo-relative `lib/` paths so they participate in the cycle graph.
    final nameMatch = RegExp(
      r'^name:\s*(\S+)',
      multiLine: true,
    ).firstMatch(await pubspec.readAsString());
    final packageName = nameMatch?.group(1);

    return Isolate.run(
      () => DartAstAnalyzer().detectImportCyclesInSources(
        dartSources,
        packageName: packageName,
      ),
    );
  }

  Future<List<Finding>> _securityFindings(
    String directory,
    String lim, {
    String? since,
    String? until,
    required List<String> allowedEmails,
    required bool checkFreshness,
    required String? branch,
  }) async {
    final secretsFuture = SecretsScanner(runner).findSecrets(
      directory,
      limit: lim,
      since: since,
      until: until,
      branch: branch,
    );
    final complianceFuture = ComplianceScanner(runner).scanComplianceIssues(
      directory,
      limit: lim,
      since: since,
      until: until,
      allowedEmails: allowedEmails,
    );

    final freshness = <FreshnessResult>[];
    final client = httpClient;
    if (checkFreshness && client != null) {
      final manifests = await DependencyManifestParser(
        runner,
      ).parseDependencyManifests(directory);
      final checker = DependencyFreshnessChecker(client);
      for (final e in manifests.ecosystems) {
        freshness.addAll(await checker.checkFreshness(e.dependencies, e.type));
      }
    }

    return <Finding>[
      ..._classifier.fromSecrets(await secretsFuture),
      ..._classifier.fromCompliance(await complianceFuture),
      ..._classifier.fromDependencyFreshness(freshness),
    ];
  }
}
