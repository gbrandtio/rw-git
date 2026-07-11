import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

class _CountingInterceptor implements HttpInterceptor {
  final List<String> log;
  final String name;

  _CountingInterceptor(this.name, this.log);

  @override
  Future<RwHttpResponse> intercept(
    RwHttpRequest request,
    Future<RwHttpResponse> Function(RwHttpRequest request) next,
  ) async {
    log.add('$name:before');
    final response = await next(request);
    log.add('$name:after');
    return response;
  }
}

void main() {
  group('Interceptor chain ordering', () {
    test(
      'runs interceptors outermost-first around the terminal handler',
      () async {
        final log = <String>[];
        final url = Uri.parse('https://example.com/foo');
        final client = MockHttpClient(
          interceptors: [
            _CountingInterceptor('outer', log),
            _CountingInterceptor('inner', log),
          ],
        );
        client.setMockResponse('GET', url, 200, 'ok');

        await client.get(url);

        expect(log, [
          'outer:before',
          'inner:before',
          'inner:after',
          'outer:after',
        ]);
      },
    );

    test(
      'retry interceptor composes with a logging-style interceptor',
      () async {
        final log = <String>[];
        final url = Uri.parse('https://example.com/foo');
        final client = MockHttpClient(
          interceptors: [
            _CountingInterceptor('outer', log),
            RetryInterceptor(baseDelay: Duration.zero, delay: (_) async {}),
          ],
        );
        client.setMockResponses('GET', url, [
          const RwHttpResponse(statusCode: 503, body: 'unavailable'),
          const RwHttpResponse(statusCode: 200, body: 'ok'),
        ]);

        final response = await client.get(url);

        expect(response.statusCode, 200);
        // The outer interceptor only sees one logical before/after pair, even
        // though the retry interceptor invoked the terminal handler twice.
        expect(log, ['outer:before', 'outer:after']);
        expect(client.capturedRequests, hasLength(2));
      },
    );
  });
}
