/// ----------------------------------------------------------------------------
/// report_orchestrator.dart
/// ----------------------------------------------------------------------------
/// Runs the relevant analysis algorithms server-side, classifies their DTOs
/// into severity-banded findings, correlates them into compound findings, and
/// returns a bounded [ReportPayload]. This moves the entire interpret +
/// correlate + rank workload out of the LLM and into deterministic Dart, so a
/// small model can produce a full report from a single tool call.
library;

import 'package:rw_git/src/constants.dart';
import 'package:rw_git/src/core/network/http_client.dart';
import 'package:rw_git/src/core/process_runner.dart';
import 'package:rw_git/src/intelligence/architecture/logical_coupling_algorithm.dart';
import 'package:rw_git/src/intelligence/architecture/refactoring_detection_algorithm.dart';
import 'package:rw_git/src/intelligence/history/algorithms/code_volatility_algorithm.dart';
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
import 'package:rw_git/src/intelligence/static_analysis/metrics/bounded_lexical_metrics_sampler.dart';
import 'package:rw_git/src/models/dependency_freshness_dto.dart';

import 'compound_finding_correlator.dart';
import 'finding.dart';
import 'finding_classifier.dart';
import 'report_payload.dart';

/// Builds pre-interpreted report payloads for the report meta-tools.
class ReportOrchestrator {
  final ProcessRunner runner;

  /// Optional HTTP client used only for opt-in dependency-freshness lookups.
  final RwHttpClient? httpClient;

  const ReportOrchestrator(this.runner, {this.httpClient});

  static const _classifier = FindingClassifier();
  static const _correlator = CompoundFindingCorrelator();

  /// Technical report: complexity, churn, ownership, bug hotspots, coupling,
  /// and volatility — the code-quality/architecture surface.
  Future<ReportPayload> technicalReport(
    String directory, {
    String? limit,
  }) async {
    final lim = limit ?? defaultCommitLimit;
    final findings = await _technicalFindings(directory, lim);
    return ReportPayload.fromFindings(
      reportType: 'technical',
      findings: findings,
      compounds: _correlator.correlate(findings),
      metadata: {'directory': directory, 'commit_limit': lim},
    );
  }

  /// Security report: exposed secrets, commit compliance, and (opt-in)
  /// dependency freshness.
  Future<ReportPayload> securityReport(
    String directory, {
    String? limit,
    List<String> allowedEmails = const [],
    bool checkFreshness = false,
    String? branch,
  }) async {
    final lim = limit ?? defaultCommitLimit;
    final findings = await _securityFindings(
      directory,
      lim,
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
        'freshness_checked': checkFreshness && httpClient != null,
      },
    );
  }

  /// Project-management report: knowledge concentration (bus factor + per-file
  /// ownership), delivery bottlenecks (bug hotspots), and delivery cadence
  /// (velocity trend, author concentration, burnout-window work).
  Future<ReportPayload> pmReport(
    String directory, {
    String? limit,
  }) async {
    final lim = limit ?? defaultCommitLimit;
    final busFactor =
        await BusFactorAlgorithm(runner).execute(directory, limit: lim);
    final churnAuthors = await ChurnHeuristic(runner)
        .calculateChurnWithAuthors(directory, limit: lim);
    final hotspots = await BugHotspotsHeuristic(runner)
        .calculateBugHotspots(directory, limit: lim);
    final velocity = await CommitVelocityHeuristic(runner)
        .calculateCommitVelocity(directory, limit: lim);

    final findings = <Finding>[
      ..._classifier.fromBusFactor(busFactor),
      ..._classifier.fromOwnership(churnAuthors),
      ..._classifier.fromBugHotspots(hotspots),
      ..._classifier.fromCommitVelocity(velocity),
    ];
    return ReportPayload.fromFindings(
      reportType: 'pm',
      findings: findings,
      compounds: _correlator.correlate(findings),
      metadata: {'directory': directory, 'commit_limit': lim},
    );
  }

  /// Code-review report: risk signals for code under review — exposed secrets,
  /// bug hotspots, single-owner files, complexity outliers (both the diff
  /// proxy and genuine McCabe metrics on the highest-churn files).
  Future<ReportPayload> codeReviewReport(
    String directory, {
    String? limit,
    String? branch,
  }) async {
    final lim = limit ?? defaultCommitLimit;
    final advanced = await AdvancedMetricsHeuristic(runner)
        .calculateAdvancedMetrics(directory, limit: lim);
    final churn =
        await ChurnHeuristic(runner).calculateChurn(directory, limit: lim);
    final churnAuthors = await ChurnHeuristic(runner)
        .calculateChurnWithAuthors(directory, limit: lim);
    final hotspots = await BugHotspotsHeuristic(runner)
        .calculateBugHotspots(directory, limit: lim);
    final secrets = await SecretsScanner(runner)
        .findSecrets(directory, limit: lim, branch: branch);
    final lexicalMetrics = await const BoundedLexicalMetricsSampler()
        .sampleTopChurnFiles(directory, churn.fileChurn);

    final findings = <Finding>[
      ..._classifier.fromSecrets(secrets),
      ..._classifier.fromComplexity(advanced),
      ..._classifier.fromLexicalMetrics(lexicalMetrics),
      ..._classifier.fromOwnership(churnAuthors),
      ..._classifier.fromBugHotspots(hotspots),
      ..._classifier.fromChurn(churn),
    ];
    return ReportPayload.fromFindings(
      reportType: 'code_review',
      findings: findings,
      compounds: _correlator.correlate(findings),
      metadata: {'directory': directory, 'commit_limit': lim},
    );
  }

  /// High-level deep audit: the union of technical + security signals in one
  /// pass, which is where cross-tool compound findings are most likely to
  /// surface.
  Future<ReportPayload> repositoryAudit(
    String directory, {
    String? limit,
    List<String> allowedEmails = const [],
    bool checkFreshness = false,
    String? branch,
  }) async {
    final lim = limit ?? defaultCommitLimit;
    final busFactor =
        await BusFactorAlgorithm(runner).execute(directory, limit: lim);
    final megaCommits = await MegaCommitsHeuristic(runner)
        .findMegaCommits(directory, limit: lim);
    final suspiciousCommits = await SuspiciousCommitsHeuristic(runner)
        .findSuspiciousCommits(directory, limit: lim);
    final findings = <Finding>[
      ..._classifier.fromBusFactor(busFactor),
      ..._classifier.fromMegaCommits(megaCommits),
      ..._classifier.fromSuspiciousCommits(suspiciousCommits),
      ...await _technicalFindings(directory, lim),
      ...await _securityFindings(
        directory,
        lim,
        allowedEmails: allowedEmails,
        checkFreshness: checkFreshness,
        branch: branch,
      ),
    ];
    return ReportPayload.fromFindings(
      reportType: 'repository_audit',
      findings: findings,
      compounds: _correlator.correlate(findings),
      maxTopFindings: 12,
      maxCompoundFindings: 8,
      metadata: {'directory': directory, 'commit_limit': lim},
    );
  }

  Future<List<Finding>> _technicalFindings(String directory, String lim) async {
    final advanced = await AdvancedMetricsHeuristic(runner)
        .calculateAdvancedMetrics(directory, limit: lim);
    final churn =
        await ChurnHeuristic(runner).calculateChurn(directory, limit: lim);
    final churnAuthors = await ChurnHeuristic(runner)
        .calculateChurnWithAuthors(directory, limit: lim);
    final hotspots = await BugHotspotsHeuristic(runner)
        .calculateBugHotspots(directory, limit: lim);
    final coupling =
        await LogicalCouplingAlgorithm(runner).execute(directory, limit: lim);
    final volatility =
        await CodeVolatilityAlgorithm(runner).execute(directory, limit: lim);
    // Genuine McCabe/maintainability metrics for a bounded top-churn sample
    // (ADR-0014) — churn is already computed above, so this costs no extra
    // git calls, only N bounded file reads.
    final lexicalMetrics = await const BoundedLexicalMetricsSampler()
        .sampleTopChurnFiles(directory, churn.fileChurn);
    final refactorings = await RefactoringDetectionAlgorithm(runner)
        .execute(directory, limit: lim);

    final findings = <Finding>[
      ..._classifier.fromComplexity(advanced),
      ..._classifier.fromLexicalMetrics(lexicalMetrics),
      ..._classifier.fromChurn(churn),
      ..._classifier.fromOwnership(churnAuthors),
      ..._classifier.fromBugHotspots(hotspots),
      ..._classifier.fromLogicalCoupling(coupling),
      ..._classifier.fromVolatility(volatility),
      ..._classifier.fromRefactoringActivity(refactorings),
    ];
    // Refactoring-aware pass (RA-SZZ insight): churn/volatility findings on
    // files the refactorings renamed are downgraded one band.
    return _classifier.applyRefactoringContext(findings, refactorings);
  }

  Future<List<Finding>> _securityFindings(
    String directory,
    String lim, {
    required List<String> allowedEmails,
    required bool checkFreshness,
    required String? branch,
  }) async {
    final secrets = await SecretsScanner(runner)
        .findSecrets(directory, limit: lim, branch: branch);
    final compliance = await ComplianceScanner(runner).scanComplianceIssues(
      directory,
      limit: lim,
      allowedEmails: allowedEmails,
    );

    final freshness = <FreshnessResult>[];
    final client = httpClient;
    if (checkFreshness && client != null) {
      final manifests = await DependencyManifestParser(runner)
          .parseDependencyManifests(directory);
      final checker = DependencyFreshnessChecker(client);
      for (final e in manifests.ecosystems) {
        freshness.addAll(await checker.checkFreshness(e.dependencies, e.type));
      }
    }

    return <Finding>[
      ..._classifier.fromSecrets(secrets),
      ..._classifier.fromCompliance(compliance),
      ..._classifier.fromDependencyFreshness(freshness),
    ];
  }
}
