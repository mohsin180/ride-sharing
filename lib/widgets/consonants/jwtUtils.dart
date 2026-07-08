import 'dart:convert';

/// Client-side JWT claim reader. Used so we can route the user to the
/// right post-login experience (driver vs passenger) without an extra
/// backend round-trip — the token the gateway issued already carries
/// everything we need.
///
/// Does NOT verify the signature: signature verification is the backend's
/// job. We only read claims the backend has already vouched for.
class JwtUtils {
  JwtUtils._();

  /// Returns the decoded payload (middle segment) of a JWT, or null if
  /// the token is malformed.
  static Map<String, dynamic>? decode(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final json = jsonDecode(decoded);
      return json is Map<String, dynamic> ? json : null;
    } catch (_) {
      return null;
    }
  }

  static String? extractRole(String token) =>
      decode(token)?['role'] as String?;

  static String? extractUserId(String token) =>
      decode(token)?['userId'] as String?;

  static String? extractEmail(String token) =>
      decode(token)?['email'] as String?;

  static String? extractGender(String token) =>
      decode(token)?['gender'] as String?;

  /// True when the token's `exp` claim is in the past (with a small skew
  /// allowance). A malformed token, or one with no `exp`, is treated as NOT
  /// expired — the backend stays the authority and rejects it on the next
  /// call; we only use this to avoid auto-logging-in on a clearly-dead token.
  static bool isExpired(String token) {
    final exp = decode(token)?['exp'];
    if (exp is! num) return false;
    final expiryMs = exp.toInt() * 1000;
    // 10s skew so a just-expired token still routes cleanly to login.
    return DateTime.now().millisecondsSinceEpoch >= expiryMs - 10000;
  }
}
