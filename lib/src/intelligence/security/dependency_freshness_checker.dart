import 'package:rw_git/src/core/network/http_client.dart';
import 'package:rw_git/src/core/network/network_exceptions.dart';
import 'package:rw_git/src/models/dependency_freshness_dto.dart';
import 'package:rw_git/src/models/dependency_manifest_dto.dart';

import 'registry_adapters.dart';
import 'semver_compare.dart';

/// ----------------------------------------------------------------------------
/// dependency_freshness_checker.dart
/// ----------------------------------------------------------------------------
/// Compares declared dependency versions against the latest version
/// available in each ecosystem's package registry. Performs network calls
/// (via the injected RwHttpClient) — this is the opt-in piece of
/// analyze_dependency_drift, never invoked unless explicitly requested.
///
/// Each dependency is checked independently: a failure for one (network
/// error, 404, malformed response) never aborts the batch — it is reported
/// as an 'unknown' classification with an explanatory error message.
class DependencyFreshnessChecker {
  final RwHttpClient client;

  DependencyFreshnessChecker(this.client);

  Future<List<FreshnessResult>> checkFreshness(
    List<DependencyEntry> dependencies,
    String ecosystemType, {
    int concurrency = 4,
  }) async {
    final results = List<FreshnessResult?>.filled(dependencies.length, null);
    var nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        final index = nextIndex;
        if (index >= dependencies.length) return;
        nextIndex++;
        results[index] = await _checkOne(dependencies[index], ecosystemType);
      }
    }

    final workerCount = concurrency < dependencies.length
        ? concurrency
        : dependencies.length;
    await Future.wait(List.generate(workerCount, (_) => worker()));

    return results.cast<FreshnessResult>();
  }

  Future<FreshnessResult> _checkOne(
    DependencyEntry entry,
    String ecosystemType,
  ) async {
    final request = buildRegistryRequest(ecosystemType, entry.name);
    if (request == null) {
      return FreshnessResult(
        name: entry.name,
        declaredVersion: entry.declaredVersion,
        classification: 'unknown',
        error: 'No registry lookup available for ecosystem $ecosystemType',
      );
    }

    try {
      final response = await client.get(request.uri, headers: request.headers);
      if (response.statusCode != 200) {
        return FreshnessResult(
          name: entry.name,
          declaredVersion: entry.declaredVersion,
          classification: 'unknown',
          error: 'Registry lookup failed with status ${response.statusCode}',
        );
      }

      final latest = extractLatestVersion(request, response.body);
      if (latest == null) {
        return FreshnessResult(
          name: entry.name,
          declaredVersion: entry.declaredVersion,
          classification: 'unknown',
          error: 'Could not extract latest version from registry response',
        );
      }

      return FreshnessResult(
        name: entry.name,
        declaredVersion: entry.declaredVersion,
        latestVersion: latest,
        classification: classifyFreshness(entry.declaredVersion, latest),
      );
    } on RwHttpTransportException catch (e) {
      return FreshnessResult(
        name: entry.name,
        declaredVersion: entry.declaredVersion,
        classification: 'unknown',
        error: 'Registry lookup failed: ${e.message}',
      );
    } on RwHttpException catch (e) {
      return FreshnessResult(
        name: entry.name,
        declaredVersion: entry.declaredVersion,
        classification: 'unknown',
        error: 'Registry lookup failed: ${e.message}',
      );
    } catch (e) {
      return FreshnessResult(
        name: entry.name,
        declaredVersion: entry.declaredVersion,
        classification: 'unknown',
        error: 'Registry lookup failed: $e',
      );
    }
  }
}
