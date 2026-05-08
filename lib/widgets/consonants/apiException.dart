/// Thrown by the API client (and by service layers that wrap it) for any
/// non-2xx response or transport failure. Carries a numeric [statusCode]
/// (0 for transport-level errors) and a user-facing [message].
///
/// Throw or rethrow this from anywhere; surface it via [ErrorHandler].
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  bool get isBadRequest => statusCode == 400;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isServerError => statusCode >= 500;
  bool get isNetworkError => statusCode == 0;

  @override
  String toString() => message;
}
