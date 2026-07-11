import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'http_client.dart';
import 'http_interceptor.dart';
import 'http_interceptor_chain.dart';
import 'network_exceptions.dart';

/// ----------------------------------------------------------------------------
/// standard_http_client.dart
/// ----------------------------------------------------------------------------
/// Default RwHttpClient implementation, backed by package:http.
class StandardHttpClient implements RwHttpClient {
  final List<HttpInterceptor> interceptors;
  final http.Client _client;
  final Duration defaultTimeout;

  StandardHttpClient({
    this.interceptors = const [],
    http.Client? client,
    this.defaultTimeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

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
    return runInterceptorChain(interceptors, request, _performRequest);
  }

  Future<RwHttpResponse> _performRequest(RwHttpRequest request) async {
    try {
      final httpRequest = http.Request(request.method, request.url)
        ..headers.addAll(request.headers);
      if (request.body != null) {
        httpRequest.body = request.body!;
      }

      final streamedResponse = await _client
          .send(httpRequest)
          .timeout(request.timeout ?? defaultTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      return RwHttpResponse(
        statusCode: response.statusCode,
        body: response.body,
        headers: response.headers,
      );
    } on TimeoutException catch (e) {
      throw RwHttpTransportException(
        'Request to ${request.url} timed out',
        originalException: e,
      );
    } on SocketException catch (e) {
      throw RwHttpTransportException(
        'Failed to connect to ${request.url}',
        originalException: e,
      );
    } on http.ClientException catch (e) {
      throw RwHttpTransportException(
        'HTTP client error for ${request.url}: ${e.message}',
        originalException: e,
      );
    }
  }
}
