import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed accessor over the `.env` file. Loaded once in `main.dart` via
/// [Env.load], then read anywhere via the static getters below.
///
/// Adding a new variable:
///   1. Add it to `.env` (locally) and `.env.example` (committed).
///   2. Add a getter here so the rest of the app stays string-key-free.
///   3. Optionally throw in [_require] if it must be present.
class Env {
  Env._();

  /// Load the local `.env` file. Call once from `main()` *before* `runApp`.
  /// Keeps going on failure so the app still boots in case of a missing
  /// file in CI/tests — individual getters fall back to safe defaults.
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // .env not bundled (e.g. unit test) — fall through to defaults.
    }
  }

  static String _read(String key, {String fallback = ''}) {
    return dotenv.maybeGet(key)?.trim() ?? fallback;
  }

  static String _require(String key) {
    final value = _read(key);
    if (value.isEmpty) {
      throw StateError(
        'Missing required env var "$key". Add it to your .env file '
        '(see .env.example for the full list).',
      );
    }
    return value;
  }

  /// Spring Boot REST API base URL. Falls back to localhost so a missing
  /// `.env` during development doesn't crash the boot — but production
  /// builds should always have this set.
  static String get apiBaseUrl =>
      _read('API_BASE_URL', fallback: 'http://localhost:8080/api/v1');

  /// Geoapify API key — used by `GeocodingService` and `RoutingService`
  /// for autocomplete, reverse geocoding, and routing. Throws if
  /// missing so requests fail loud with a useful message instead of
  /// hitting a confusing 401 from the API.
  static String get geoapifyApiKey => _require('GEOAPIFY_API_KEY');

  /// Same as [geoapifyApiKey] but returns an empty string instead of
  /// throwing — use for early validity checks where you'd rather render
  /// a "key not configured" placeholder than crash the widget.
  static String get geoapifyApiKeyOrEmpty => _read('GEOAPIFY_API_KEY');
}
