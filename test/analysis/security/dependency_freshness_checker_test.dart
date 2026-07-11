import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

class _ConcurrencyTrackingHttpClient implements RwHttpClient {
  int _inFlight = 0;
  int maxInFlight = 0;
  int requestCount = 0;

  @override
  Future<RwHttpResponse> get(
    Uri url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    requestCount++;
    _inFlight++;
    if (_inFlight > maxInFlight) maxInFlight = _inFlight;
    await Future.delayed(const Duration(milliseconds: 20));
    _inFlight--;
    return const RwHttpResponse(statusCode: 200, body: '{"version":"1.0.0"}');
  }

  @override
  Future<RwHttpResponse> send(RwHttpRequest request) =>
      get(request.url, headers: request.headers, timeout: request.timeout);
}

void main() {
  group('DependencyFreshnessChecker', () {
    test('checks a Dart dependency against pub.dev', () async {
      final client = MockHttpClient();
      final url = Uri.parse('https://pub.dev/api/packages/path');
      client.setMockResponse('GET', url, 200, '{"latest":{"version":"1.5.0"}}');

      final checker = DependencyFreshnessChecker(client);
      final results = await checker.checkFreshness([
        const DependencyEntry(
          name: 'path',
          declaredVersion: '^1.2.3',
          isPinned: false,
        ),
      ], 'dart');

      expect(results, hasLength(1));
      expect(results.first.latestVersion, '1.5.0');
      expect(results.first.classification, 'minor_behind');
    });

    test('URL-encodes scoped npm package names', () async {
      final client = MockHttpClient();
      final url = Uri.parse('https://registry.npmjs.org/@scope%2fname/latest');
      client.setMockResponse('GET', url, 200, '{"version":"2.0.0"}');

      final checker = DependencyFreshnessChecker(client);
      final results = await checker.checkFreshness([
        const DependencyEntry(
          name: '@scope/name',
          declaredVersion: '1.0.0',
          isPinned: true,
        ),
      ], 'npm');

      expect(results.first.latestVersion, '2.0.0');
      expect(results.first.classification, 'major_behind');
    });

    test('sends User-Agent header for crates.io lookups', () async {
      final client = MockHttpClient();
      final url = Uri.parse('https://crates.io/api/v1/crates/serde');
      client.setMockResponse(
        'GET',
        url,
        200,
        '{"crate":{"max_stable_version":"1.0.0"}}',
      );

      final checker = DependencyFreshnessChecker(client);
      await checker.checkFreshness([
        const DependencyEntry(
          name: 'serde',
          declaredVersion: '1.0.0',
          isPinned: true,
        ),
      ], 'rust');

      expect(client.capturedRequests, hasLength(1));
      expect(
        client.capturedRequests.first.headers['User-Agent'],
        contains('rw-git'),
      );
    });

    test('one failed lookup does not affect the rest of the batch', () async {
      final client = MockHttpClient();
      final okUrl = Uri.parse('https://pypi.org/pypi/requests/json');
      final missingUrl = Uri.parse('https://pypi.org/pypi/totally-fake/json');
      client.setMockResponse(
        'GET',
        okUrl,
        200,
        '{"info":{"version":"2.31.0"}}',
      );
      client.setMockResponse('GET', missingUrl, 404, 'not found');

      final checker = DependencyFreshnessChecker(client);
      final results = await checker.checkFreshness([
        const DependencyEntry(
          name: 'requests',
          declaredVersion: '2.26.0',
          isPinned: true,
        ),
        const DependencyEntry(
          name: 'totally-fake',
          declaredVersion: '1.0.0',
          isPinned: true,
        ),
      ], 'python');

      final ok = results.firstWhere((r) => r.name == 'requests');
      final missing = results.firstWhere((r) => r.name == 'totally-fake');

      expect(ok.classification, 'minor_behind');
      expect(missing.classification, 'unknown');
      expect(missing.error, isNotNull);
    });

    test(
      'transport failure for one dependency yields unknown, not a throw',
      () async {
        final client = MockHttpClient();
        final url = Uri.parse('https://rubygems.org/api/v1/gems/rails.json');
        client.setMockError('GET', url, Exception('connection reset'));

        final checker = DependencyFreshnessChecker(client);
        final results = await checker.checkFreshness([
          const DependencyEntry(
            name: 'rails',
            declaredVersion: '6.1.4',
            isPinned: true,
          ),
        ], 'ruby');

        expect(results.first.classification, 'unknown');
        expect(results.first.error, isNotNull);
      },
    );

    test('respects the concurrency cap', () async {
      final client = _ConcurrencyTrackingHttpClient();

      final dependencies = List.generate(
        10,
        (i) => DependencyEntry(
          name: 'pkg$i',
          declaredVersion: '1.0.0',
          isPinned: true,
        ),
      );

      final checker = DependencyFreshnessChecker(client);
      final results = await checker.checkFreshness(
        dependencies,
        'ruby',
        concurrency: 3,
      );

      expect(results, hasLength(10));
      expect(client.requestCount, 10);
      expect(client.maxInFlight, lessThanOrEqualTo(3));
      expect(client.maxInFlight, greaterThan(1));
    });
  });
}
