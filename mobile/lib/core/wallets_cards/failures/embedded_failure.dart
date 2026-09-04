import 'package:flutter/foundation.dart';

/// Base class for all embedded wallet failures.
/// All failures carry a human-readable [message] and optional error code.
@immutable
abstract class EmbeddedFailure {
  final String message;
  final int? statusCode;
  final Object? cause;

  const EmbeddedFailure(this.message, {this.statusCode, this.cause});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmbeddedFailure &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          statusCode == other.statusCode;

  @override
  int get hashCode => message.hashCode ^ statusCode.hashCode;

  @override
  String toString() => '$runtimeType: $message (${statusCode ?? "no status code"})';
}

/// 5xx or unexpected server response
class EmbeddedServerFailure extends EmbeddedFailure {
  const EmbeddedServerFailure(super.message, {super.statusCode, super.cause});
}

/// Local storage read/write error
class EmbeddedCacheFailure extends EmbeddedFailure {
  const EmbeddedCacheFailure(super.message, {super.statusCode, super.cause});
}

/// No connectivity or request timeout
class EmbeddedNetworkFailure extends EmbeddedFailure {
  const EmbeddedNetworkFailure(super.message, {super.statusCode, super.cause});
}

/// Malformed request / validation failure
class EmbeddedValidationFailure extends EmbeddedFailure {
  final List<String>? errors;

  const EmbeddedValidationFailure(super.message, {super.statusCode, super.cause, this.errors});
}

/// HTTP 429 Too Many Requests
class EmbeddedRateLimitFailure extends EmbeddedFailure {
  final int? retryAfterSeconds;

  const EmbeddedRateLimitFailure(super.message, {super.statusCode, super.cause, this.retryAfterSeconds});
}

/// HTTP 404 Resource Not Found
class EmbeddedNotFoundFailure extends EmbeddedFailure {
  const EmbeddedNotFoundFailure(super.message, {super.statusCode, super.cause});
}

/// HTTP 401 Unauthorized / Token Expired
class EmbeddedAuthenticationFailure extends EmbeddedFailure {
  const EmbeddedAuthenticationFailure(super.message, {super.statusCode, super.cause});
}

/// HTTP 403 Forbidden / Insufficient Permissions
class EmbeddedAuthorizationFailure extends EmbeddedFailure {
  const EmbeddedAuthorizationFailure(super.message, {super.statusCode, super.cause});
}
