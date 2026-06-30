import 'http_client.dart';
import 'http_interceptor.dart';

/// ----------------------------------------------------------------------------
/// http_interceptor_chain.dart
/// ----------------------------------------------------------------------------
/// Folds a list of [HttpInterceptor]s around a [terminal] handler (the
/// function that actually performs the request) into a single onion-style
/// chain. Shared by StandardHttpClient and MockHttpClient so interceptor
/// behavior (in particular retries) is identical and testable against the
/// mock transport.
Future<RwHttpResponse> runInterceptorChain(
  List<HttpInterceptor> interceptors,
  RwHttpRequest request,
  Future<RwHttpResponse> Function(RwHttpRequest request) terminal,
) {
  var handler = terminal;
  for (final interceptor in interceptors.reversed) {
    final next = handler;
    handler = (req) => interceptor.intercept(req, next);
  }
  return handler(request);
}
