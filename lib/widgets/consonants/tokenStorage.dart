import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Tokenstorage {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = "token";
  static const _onboardingTokenKey = "onboardingToken";
  static const _pendingUserIdKey = "pendingUserId";

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  static Future<bool> hasToken() async {
    final token = await _storage.read(key: _tokenKey);
    return token != null && token.isNotEmpty;
  }

  // ── unfinished signup ──────────────────────────────────────────
  // Registration hands back a user id and an onboarding token but no real
  // token, so without persisting them the account is orphaned the moment the
  // OS kills the app — which it routinely does while the user is off opening
  // the verification email.

  static Future<void> saveOnboarding({
    required String userId,
    required String onboardingToken,
  }) async {
    await _storage.write(key: _pendingUserIdKey, value: userId);
    await _storage.write(key: _onboardingTokenKey, value: onboardingToken);
  }

  static Future<String?> getOnboardingToken() =>
      _storage.read(key: _onboardingTokenKey);

  static Future<String?> getPendingUserId() =>
      _storage.read(key: _pendingUserIdKey);

  /// Called once a role is chosen and a real token exists.
  static Future<void> clearOnboarding() async {
    await _storage.delete(key: _pendingUserIdKey);
    await _storage.delete(key: _onboardingTokenKey);
  }
}
