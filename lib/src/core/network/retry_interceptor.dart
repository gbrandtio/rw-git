import 'dart:async';
import 'dart:math';

import 'http_client.dart';
import 'http_interceptor.dart';
import 'network_exceptions.dart';

/// ----------------------------------------------------------------------------
/// retry_interceptor.dart
/// ----------------------------------------------------------------------------
/// Retries requests with exponential backoff, but only for a defined subset
/// of transient failures:
///   - HTTP responses whose status code is in [retryableStatusCodes]
///     (default: 429, 502, 503, 504).
///   - Thrown transport-level errors (RwHttpTransportException), e.g.
///     timeouts or connection failures.
///
/// All other outcomes (2xx/3xx, and non-retryable 4xx/5xx like 400/401/403/404)
/// are returned/thrown immediately on the first attempt. After [maxRetries]
/// attempts are exhausted, the last response is returned as-is (or the last
/// transport error is rethrown) so the caller can see the real outcome.
class RetryInterceptor implements HttpInterceptor {
  final int maxRetries;
  final Duration baseDelay;
  final Duration maxDelay;
  final Set<int> retryableStatusCodes;
  final Future<void> Function(Duration delay) delay;
  final Random random;

  RetryInterceptor({
    this.maxRetries = 3,
    this.baseDelay = const Duration(milliseconds: 200),
    this.maxDelay = const Duration(seconds: 5),
    Set<int>? retryableStatusCodes,
    Future<void> Function(Duration delay)? delay,
    Random? random,
  }) : retryableStatusCodes =
           retryableStatusCodes ?? const {429, 502, 503, 504},
       delay = delay ?? Future.delayed,
       random = random ?? Random();

  @override
  Future<RwHttpResponse> intercept(
    RwHttpRequest request,
    Future<RwHttpResponse> Function(RwHttpRequest request) next,
  ) async {
    var attempt = 0;
    while (true) {
      try {
        final response = await next(request.copyWith(attempt: attempt));
        final shouldRetry =
            retryableStatusCodes.contains(response.statusCode) &&
            attempt < maxRetries;
        if (!shouldRetry) {
          return response;
        }
        await delay(_delayFor(attempt, response));
        attempt++;
      } on RwHttpTransportException {
        if (attempt >= maxRetries) {
          rethrow;
        }
        await delay(_delayFor(attempt, null));
        attempt++;
      }
    }
  }

  Duration _delayFor(int attempt, RwHttpResponse? response) {
    final retryAfter = _retryAfterDelay(response);
    if (retryAfter != null) {
      return retryAfter > maxDelay ? maxDelay : retryAfter;
    }
    final exponential = baseDelay * pow(2, attempt).toInt();
    final jitter = Duration(milliseconds: random.nextInt(100));
    final total = exponential + jitter;
    return total > maxDelay ? maxDelay : total;
  }

  Duration? _retryAfterDelay(RwHttpResponse? response) {
    if (response == null) return null;
    if (response.statusCode != 429 && response.statusCode != 503) {
      return null;
    }
    final headerValue =
        response.headers['retry-after'] ?? response.headers['Retry-After'];
    if (headerValue == null) return null;
    final seconds = int.tryParse(headerValue.trim());
    if (seconds == null) return null;
    return Duration(seconds: seconds);
  }
}
