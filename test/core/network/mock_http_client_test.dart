import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

void main() {
  group('MockHttpClient', () {
    test('returns mocked response', () async {
      final client = MockHttpClient();
      final url = Uri.parse('https://example.com/foo');
      client.setMockResponse('GET', url, 200, '{"ok":true}');

      final response = await client.get(url);
      expect(response.statusCode, 200);
      expect(response.body, '{"ok":true}');
    });

    test('returns queued responses in order', () async {
      final client = MockHttpClient();
      final url = Uri.parse('https://example.com/foo');
      client.setMockResponses('GET', url, [
        const RwHttpResponse(statusCode: 503, body: 'unavailable'),
        const RwHttpResponse(statusCode: 200, body: 'ok'),
      ]);

      final first = await client.get(url);
      expect(first.statusCode, 503);
      final second = await client.get(url);
      expect(second.statusCode, 200);
      // Last queued response repeats for subsequent calls.
      final third = await client.get(url);
      expect(third.statusCode, 200);
    });

    test('throws RwHttpException for unmocked key', () async {
      final client = MockHttpClient();
      final url = Uri.parse('https://example.com/unmocked');
      expect(() => client.get(url), throwsA(isA<RwHttpException>()));
    });

    test('simulated transport error is thrown', () async {
      final client = MockHttpClient();
      final url = Uri.parse('https://example.com/timeout');
      client.setMockError('GET', url, Exception('boom'));

      expect(() => client.get(url), throwsA(isA<RwHttpTransportException>()));
    });

    test('captures sent requests', () async {
      final client = MockHttpClient();
      final url = Uri.parse('https://example.com/foo');
      client.setMockResponse('GET', url, 200, 'ok');

      await client.get(url, headers: {'X-Test': '1'});
      expect(client.capturedRequests, hasLength(1));
      expect(client.capturedRequests.first.headers['X-Test'], '1');
    });
  });
}
