/// ----------------------------------------------------------------------------
/// network_exceptions.dart
/// ----------------------------------------------------------------------------
/// Strongly typed exceptions for the rw_git networking layer.
library;

/// A transport-level failure (timeout, DNS failure, connection refused, etc.)
/// normalized away from the underlying HTTP implementation.
class RwHttpTransportException implements Exception {
  final String message;
  final Object? originalException;

  RwHttpTransportException(this.message, {this.originalException});

  @override
  String toString() =>
      'RwHttpTransportException: $message'
      '${originalException != null ? '\nOriginal exception: $originalException' : ''}';
}

/// A terminal HTTP-level failure surfaced to a caller after any retries
/// have been exhausted.
class RwHttpException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;

  RwHttpException(this.message, {this.statusCode, this.body});

  @override
  String toString() =>
      'RwHttpException: $message\nStatus code: $statusCode\nBody: $body';
}
