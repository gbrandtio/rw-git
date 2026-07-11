import 'http_interceptor.dart';
import 'mock_http_client.dart';
import 'standard_http_client.dart';

/// ----------------------------------------------------------------------------
/// http_client.dart
/// ----------------------------------------------------------------------------
/// Interface for performing HTTP requests, facilitating dependency inversion
/// for easier testing (MockHttpClient). Mirrors the ProcessRunner pattern
/// used for git process execution.

/// An immutable HTTP request. [attempt] is incremented by interceptors
/// (e.g. RetryInterceptor) on each retry, starting at 0 for the first try.
class RwHttpRequest {
  final String method;
  final Uri url;
  final Map<String, String> headers;
  final String? body;
  final Duration? timeout;
  final int attempt;

  const RwHttpRequest({
    required this.method,
    required this.url,
    this.headers = const {},
    this.body,
    this.timeout,
    this.attempt = 0,
  });

  RwHttpRequest copyWith({
    String? method,
    Uri? url,
    Map<String, String>? headers,
    String? body,
    Duration? timeout,
    int? attempt,
  }) {
    return RwHttpRequest(
      method: method ?? this.method,
      url: url ?? this.url,
      headers: headers ?? this.headers,
      body: body ?? this.body,
      timeout: timeout ?? this.timeout,
      attempt: attempt ?? this.attempt,
    );
  }
}

/// An HTTP response, decoupled from the underlying HTTP implementation.
class RwHttpResponse {
  final int statusCode;
  final String body;
  final Map<String, String> headers;

  const RwHttpResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });
}

abstract class RwHttpClient {
  /// Default client backed by package:http, with the given [interceptors]
  /// applied in order (first interceptor is outermost).
  factory RwHttpClient.defaultClient({List<HttpInterceptor> interceptors}) =
      StandardHttpClient;

  /// Mock client for testing. Still runs requests through [interceptors] so
  /// retry/interceptor behavior can be exercised without real network access.
  factory RwHttpClient.mock({List<HttpInterceptor> interceptors}) =
      MockHttpClient;

  /// Convenience helper for a GET request.
  Future<RwHttpResponse> get(
    Uri url, {
    Map<String, String>? headers,
    Duration? timeout,
  });

  /// Sends an arbitrary request through the interceptor chain.
  Future<RwHttpResponse> send(RwHttpRequest request);
}
