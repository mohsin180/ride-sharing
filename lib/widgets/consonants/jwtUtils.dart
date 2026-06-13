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
}
