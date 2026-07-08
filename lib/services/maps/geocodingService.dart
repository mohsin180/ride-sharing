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

  /// Search is limited to the Islamabad–Rawalpindi twin-city area. This is a
  /// Geoapify `rect` boundary filter — `rect:lon1,lat1,lon2,lat2` (SW corner
  /// → NE corner) — so autocomplete only ever returns places inside this box.
  /// Widen/move the box here if the service area changes.
  static const String _searchAreaFilter = 'rect:72.80,33.40,73.35,33.85';

  /// Centre of the twin cities — biases ranking toward the middle of the area.
  static const LatLng _searchAreaBias = LatLng(33.62, 73.04);

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
  /// Results are hard-limited to the Islamabad–Rawalpindi area via
  /// [_searchAreaFilter], so only places in those two cities are returned.
  /// [text] is the user's typed query. [bias] (optional) nudges ranking
  /// toward a coordinate (e.g. the user's location); it defaults to the area
  /// centre. [countryCode] is accepted for call-site compatibility but the
  /// area box already constrains results far more tightly than a country.
  Future<List<PlaceSuggestion>> autocomplete(
    String text, {
    LatLng? bias,
    String? countryCode = 'pk',
    int limit = 5,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];

    final biasPoint = bias ?? _searchAreaBias;
    final params = <String, String>{
      'text': trimmed,
      'limit': '$limit',
      'apiKey': _apiKey,
      // Restrict suggestions to the Islamabad–Rawalpindi bounding box.
      'filter': _searchAreaFilter,
      'bias': 'proximity:${biasPoint.longitude},${biasPoint.latitude}',
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
