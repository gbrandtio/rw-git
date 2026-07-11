import 'http_client.dart';
import 'http_interceptor.dart';
import 'http_interceptor_chain.dart';
import 'network_exceptions.dart';

/// ----------------------------------------------------------------------------
/// mock_http_client.dart
/// ----------------------------------------------------------------------------
/// Mock RwHttpClient for testing. Requests are still run through the same
/// interceptor chain as StandardHttpClient, so retry behavior can be
/// exercised without real network access.
class MockHttpClient implements RwHttpClient {
  final List<HttpInterceptor> interceptors;
  final Map<String, List<RwHttpResponse>> _mockResponses = {};
  final Map<String, Object> _mockErrors = {};
  final List<RwHttpRequest> capturedRequests = [];

  MockHttpClient({this.interceptors = const []});

  String _key(String method, Uri url) => '$method $url';

  /// Queues a single mock response for [method]/[url]. Calling this multiple
  /// times for the same key enqueues additional responses, returned in order.
  void setMockResponse(
    String method,
    Uri url,
    int statusCode,
    String body, {
    Map<String, String>? headers,
  }) {
    setMockResponses(method, url, [
      RwHttpResponse(
        statusCode: statusCode,
        body: body,
        headers: headers ?? const {},
      ),
    ]);
  }

  /// Queues a sequence of responses for [method]/[url], returned in order on
  /// successive calls. Useful for testing retry behavior (e.g. two 503s
  /// followed by a 200).
  void setMockResponses(
    String method,
    Uri url,
    List<RwHttpResponse> responses,
  ) {
    final key = _key(method, url);
    _mockResponses.putIfAbsent(key, () => []).addAll(responses);
  }

  /// Simulates a transport-level failure (e.g. timeout) for [method]/[url].
  void setMockError(String method, Uri url, Object error) {
    _mockErrors[_key(method, url)] = error;
  }

  @override
  Future<RwHttpResponse> get(
    Uri url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) {
    return send(
      RwHttpRequest(
        method: 'GET',
        url: url,
        headers: headers ?? const {},
        timeout: timeout,
      ),
    );
  }

  @override
  Future<RwHttpResponse> send(RwHttpRequest request) {
    return runInterceptorChain(interceptors, request, _lookupMock);
  }

  Future<RwHttpResponse> _lookupMock(RwHttpRequest request) async {
    capturedRequests.add(request);
    final key = _key(request.method, request.url);

    final error = _mockErrors[key];
    if (error != null) {
      if (error is RwHttpTransportException) {
        throw error;
      }
      throw RwHttpTransportException(
        'Mocked transport failure for $key',
        originalException: error,
      );
    }

    final queue = _mockResponses[key];
    if (queue == null || queue.isEmpty) {
      throw RwHttpException('Mock result not found for $key');
    }
    // Pop from the front; if it's the last queued response, keep returning
    // it for subsequent calls rather than throwing.
    return queue.length == 1 ? queue.first : queue.removeAt(0);
  }
}
