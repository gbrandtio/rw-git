import 'http_client.dart';

/// ----------------------------------------------------------------------------
/// http_interceptor.dart
/// ----------------------------------------------------------------------------
/// Middleware contract for the HTTP networking layer. Interceptors are
/// composed into a single chain (see http_interceptor_chain.dart): each
/// interceptor decides whether/how to call [next], can wrap it in try/catch
/// for error handling, and can call it more than once to implement retries.
abstract class HttpInterceptor {
  Future<RwHttpResponse> intercept(
    RwHttpRequest request,
    Future<RwHttpResponse> Function(RwHttpRequest request) next,
  );
}
