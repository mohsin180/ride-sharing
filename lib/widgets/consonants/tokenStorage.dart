import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Tokenstorage {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = "token";
  static const _onboardingTokenKey = "onboardingToken";
  static const _pendingUserIdKey = "pendingUserId";
  static const _pendingEmailKey = "pendingEmail";

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
    String? email,
  }) async {
    await _storage.write(key: _pendingUserIdKey, value: userId);
    await _storage.write(key: _onboardingTokenKey, value: onboardingToken);
    if (email != null && email.isNotEmpty) {
      await _storage.write(key: _pendingEmailKey, value: email);
    }
  }

  /// Replaces just the onboarding token, keeping the id and email. Every
  /// onboarding call returns a fresh one, and it stays the only thing
  /// authorising the next step until identity verification finally issues a
  /// real session.
  static Future<void> saveOnboardingToken(String onboardingToken) async {
    if (onboardingToken.isEmpty) return;
    await _storage.write(key: _onboardingTokenKey, value: onboardingToken);
  }

  static Future<String?> getOnboardingToken() =>
      _storage.read(key: _onboardingTokenKey);

  static Future<String?> getPendingUserId() =>
      _storage.read(key: _pendingUserIdKey);

  /// The address the verification link was sent to. Persisted so that after
  /// a cold start the verification screen can still show WHICH email it's
  /// waiting on — without it the screen just says "your email", which is no
  /// help to someone who mistyped it.
  static Future<String?> getPendingEmail() =>
      _storage.read(key: _pendingEmailKey);

  /// Called once identity verification passes and a real account — with a
  /// real token — finally exists. Not before: every step up to that point
  /// still needs the onboarding token.
  static Future<void> clearOnboarding() async {
    await _storage.delete(key: _pendingUserIdKey);
    await _storage.delete(key: _onboardingTokenKey);
    await _storage.delete(key: _pendingEmailKey);
  }
}
