import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:ride_sharing/model/placeModels.dart';
import 'package:ride_sharing/widgets/consonants/env.dart';

/// Thrown by [GeocodingService] so callers can distinguish a real
/// service failure (network, bad key, 5xx) from "no results".
class GeocodingException implements Exception {
  final String message;
  final int? statusCode;
  const GeocodingException(this.message, {this.statusCode});

  @override
  String toString() =>
      statusCode == null ? message : '$message (HTTP $statusCode)';
}

/// Wraps Geoapify's geocoding endpoints so the rest of the app talks
/// in [PlaceSuggestion] / [PlaceDetails] instead of raw GeoJSON.
///
/// All calls require [Env.geoapifyApiKey]. The HTTP client is injected
/// so unit tests can pass a mock; production callers can use the
/// default singleton.
class GeocodingService {
  final http.Client _client;
  final String _apiKey;

  /// Default constructor — uses the env key + a fresh `http.Client`.
  GeocodingService()
      : _client = http.Client(),
        _apiKey = Env.geoapifyApiKey;

  /// Test constructor — inject a mock client and/or override key.
  GeocodingService.withClient(this._client, {String? apiKey})
      : _apiKey = apiKey ?? Env.geoapifyApiKey;

  /// Closes the underlying HTTP client. Call from `ref.onDispose` when
  /// the service is owned by a Riverpod provider.
  void dispose() => _client.close();

  /// Place autocomplete — drives the pickup/destination dropdown.
  ///
  /// [text] is the user's typed query. [bias] (optional) nudges results
  /// toward a coordinate so suggestions near the user rank higher.
  /// [countryCode] mirrors the old `countries: ["pk"]` filter; pass
  /// null to search globally.
  Future<List<PlaceSuggestion>> autocomplete(
    String text, {
    LatLng? bias,
    String? countryCode = 'pk',
    int limit = 5,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];

    final params = <String, String>{
      'text': trimmed,
      'limit': '$limit',
      'apiKey': _apiKey,
      if (countryCode != null) 'filter': 'countrycode:$countryCode',
      if (bias != null) 'bias': 'proximity:${bias.longitude},${bias.latitude}',
    };

    final uri = Uri.https('api.geoapify.com', '/v1/geocode/autocomplete', params);
    final response = await _safeGet(uri, op: 'autocomplete');

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw const GeocodingException('Malformed autocomplete response');
    }
    final features = body['features'];
    if (features is! List) return const [];

    return features
        .whereType<Map<String, dynamic>>()
        .map(PlaceSuggestion.fromGeoapifyFeature)
        .whereType<PlaceSuggestion>()
        .toList(growable: false);
  }

  /// Reverse geocoding — coordinates → human-readable address. Returns
  /// null when no feature comes back (rare, e.g. middle of the ocean).
  Future<PlaceDetails?> reverseGeocode(LatLng coords) async {
    final uri = Uri.https('api.geoapify.com', '/v1/geocode/reverse', {
      'lat': '${coords.latitude}',
      'lon': '${coords.longitude}',
      'apiKey': _apiKey,
    });

    final response = await _safeGet(uri, op: 'reverseGeocode');
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw const GeocodingException('Malformed reverse response');
    }
    final features = body['features'];
    if (features is! List || features.isEmpty) return null;

    final first = features.first;
    if (first is! Map<String, dynamic>) return null;
    return PlaceDetails.fromGeoapifyFeature(first);
  }

  /// Centralised GET so every endpoint gets the same error shape.
  /// Wraps any IO exception into a [GeocodingException] with a useful
  /// message — bubbling raw `SocketException`s into widgets is ugly.
  Future<http.Response> _safeGet(Uri uri, {required String op}) async {
    http.Response response;
    try {
      response = await _client.get(uri);
    } catch (e) {
      throw GeocodingException('$op network error: $e');
    }
    if (response.statusCode != 200) {
      throw GeocodingException(
        '$op failed',
        statusCode: response.statusCode,
      );
    }
    return response;
  }
}
