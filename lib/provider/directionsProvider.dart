import 'dart:convert';

import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:ride_sharing/widgets/consonants/env.dart';

/// Google Maps API key — sourced from `.env` (which is gitignored). The
/// native Maps SDK key in `AndroidManifest.xml` covers map rendering;
/// this is for the HTTP REST APIs (Directions, Geocoding, Places).
String get kGoogleMapsKey => Env.googleMapsKeyOrEmpty;

/// One end-to-end route between two coords.
class DirectionsResult {
  /// Trip distance in metres.
  final int distanceMeters;

  /// Trip duration in seconds.
  final int durationSeconds;

  /// The Directions-API "encoded polyline" string — handy if we ever
  /// want to ship it to a backend or cache it as text.
  final String encodedPolyline;

  /// Decoded route points, ready to drop straight into [Polyline.points].
  final List<LatLng> points;

  /// LatLng bounds that enclose the whole route — pass to
  /// `CameraUpdate.newLatLngBounds` to fit pickup → drop in view.
  final LatLngBounds bounds;

  const DirectionsResult({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.encodedPolyline,
    required this.points,
    required this.bounds,
  });

  double get distanceKm => distanceMeters / 1000.0;
  int get durationMinutes => (durationSeconds / 60).round();
}

/// Args for [directionsProvider]. Equality matters because Riverpod uses
/// it to cache results — same origin/destination = same future.
class DirectionsRequest {
  final LatLng origin;
  final LatLng destination;
  const DirectionsRequest({required this.origin, required this.destination});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DirectionsRequest &&
        other.origin.latitude == origin.latitude &&
        other.origin.longitude == origin.longitude &&
        other.destination.latitude == destination.latitude &&
        other.destination.longitude == destination.longitude;
  }

  @override
  int get hashCode => Object.hash(
        origin.latitude,
        origin.longitude,
        destination.latitude,
        destination.longitude,
      );
}

/// Calls Google Directions API for a driving route between two points.
/// Throws if the key isn't set, the network errors out, or the API
/// returns a non-OK status; the consumer renders that via
/// `AsyncValue.when(error: …)`.
final directionsProvider =
    FutureProvider.family<DirectionsResult, DirectionsRequest>((ref, req) async {
  if (kGoogleMapsKey.isEmpty) {
    throw StateError(
      'GOOGLE_MAPS_KEY missing. Set it in .env at the project root '
      '(see .env.example).',
    );
  }

  final uri = Uri.https(
    'maps.googleapis.com',
    '/maps/api/directions/json',
    {
      'origin': '${req.origin.latitude},${req.origin.longitude}',
      'destination':
          '${req.destination.latitude},${req.destination.longitude}',
      'mode': 'driving',
      'key': kGoogleMapsKey,
    },
  );

  final response = await http.get(uri);
  if (response.statusCode != 200) {
    throw HttpException(
      'Directions HTTP ${response.statusCode}: ${response.body}',
    );
  }

  final body = json.decode(response.body) as Map<String, dynamic>;
  final status = body['status'] as String?;
  if (status != 'OK') {
    throw HttpException('Directions API status: $status');
  }

  final routes = body['routes'] as List<dynamic>;
  if (routes.isEmpty) {
    throw const HttpException('Directions API returned no routes');
  }

  final route = routes.first as Map<String, dynamic>;
  final leg = (route['legs'] as List).first as Map<String, dynamic>;
  final overview = route['overview_polyline'] as Map<String, dynamic>;
  final encoded = overview['points'] as String;

  final decoded = PolylinePoints()
      .decodePolyline(encoded)
      .map((p) => LatLng(p.latitude, p.longitude))
      .toList();

  final boundsRaw = route['bounds'] as Map<String, dynamic>;
  final ne = boundsRaw['northeast'] as Map<String, dynamic>;
  final sw = boundsRaw['southwest'] as Map<String, dynamic>;

  return DirectionsResult(
    distanceMeters: (leg['distance']['value'] as num).toInt(),
    durationSeconds: (leg['duration']['value'] as num).toInt(),
    encodedPolyline: encoded,
    points: decoded,
    bounds: LatLngBounds(
      southwest: LatLng(
        (sw['lat'] as num).toDouble(),
        (sw['lng'] as num).toDouble(),
      ),
      northeast: LatLng(
        (ne['lat'] as num).toDouble(),
        (ne['lng'] as num).toDouble(),
      ),
    ),
  );
});

class HttpException implements Exception {
  final String message;
  const HttpException(this.message);
  @override
  String toString() => message;
}
