import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:ride_sharing/model/routeModels.dart';
import 'package:ride_sharing/widgets/consonants/env.dart';

/// Thrown by [RoutingService]. Mirrors `GeocodingException` so the
/// provider/UI layer can pattern-match on a shared exception shape.
class RoutingException implements Exception {
  final String message;
  final int? statusCode;
  const RoutingException(this.message, {this.statusCode});

  @override
  String toString() =>
      statusCode == null ? message : '$message (HTTP $statusCode)';
}

/// Travel modes Geoapify supports. Kept as an enum so callers don't
/// pass typo'd raw strings into the URL — the wire value is in [code].
enum TravelMode {
  drive('drive'),
  walk('walk'),
  bicycle('bicycle'),
  motorcycle('motorcycle');

  final String code;
  const TravelMode(this.code);
}

/// Wraps Geoapify Routing. Returns a decoded [RouteResult] so the UI
/// gets `List<LatLng>` ready to drop into a `PolylineLayer`, plus the
/// distance/duration metadata for the live-distance strip.
///
/// We ask for GeoJSON on the wire (the default for this endpoint) so
/// there's no encoded-polyline decoding step — Geoapify returns the
/// LineString already laid out, which removes the previous dependency
/// on `flutter_polyline_points`.
class RoutingService {
  final http.Client _client;
  final String _apiKey;

  RoutingService()
      : _client = http.Client(),
        _apiKey = Env.geoapifyApiKey;

  RoutingService.withClient(this._client, {String? apiKey})
      : _apiKey = apiKey ?? Env.geoapifyApiKey;

  void dispose() => _client.close();

  /// Computes a route between [from] and [to]. Throws on bad coords or
  /// service failure; never returns an empty-points result (Geoapify
  /// either gives a path or 4xx's).
  Future<RouteResult> route({
    required LatLng from,
    required LatLng to,
    TravelMode mode = TravelMode.drive,
  }) async {
    // Geoapify wants waypoints as "lat,lon|lat,lon" — note: lat first
    // here (the GeoJSON output later is lon,lat — Geoapify is
    // intentionally inconsistent about input vs output).
    final waypoints = '${from.latitude},${from.longitude}'
        '|${to.latitude},${to.longitude}';

    final uri = Uri.https('api.geoapify.com', '/v1/routing', {
      'waypoints': waypoints,
      'mode': mode.code,
      'apiKey': _apiKey,
    });

    http.Response response;
    try {
      response = await _client.get(uri);
    } catch (e) {
      throw RoutingException('routing network error: $e');
    }
    if (response.statusCode != 200) {
      throw RoutingException(
        'routing failed',
        statusCode: response.statusCode,
      );
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw const RoutingException('Malformed routing response');
    }
    final features = body['features'];
    if (features is! List || features.isEmpty) {
      throw const RoutingException('No route returned');
    }

    final first = features.first;
    if (first is! Map<String, dynamic>) {
      throw const RoutingException('Malformed routing feature');
    }

    final points = _extractPoints(first['geometry']);
    if (points.isEmpty) {
      throw const RoutingException('Routing geometry was empty');
    }

    final props = first['properties'];
    final distance =
        (props is Map<String, dynamic> ? props['distance'] : null) as num?;
    final time =
        (props is Map<String, dynamic> ? props['time'] : null) as num?;

    return RouteResult(
      points: points,
      distanceMeters: distance?.toDouble() ?? 0.0,
      durationSeconds: time?.toInt() ?? 0,
      bounds: LatLngBoundsLite.fromPoints(points),
    );
  }

  /// Geoapify routing geometries come back either as a `LineString`
  /// (single `[lon, lat]` pair list) or as a `MultiLineString` (list
  /// of those — happens when the route has via-points or stops). We
  /// flatten both cases into one ordered list of [LatLng].
  List<LatLng> _extractPoints(Object? geometry) {
    if (geometry is! Map<String, dynamic>) return const [];
    final type = geometry['type'];
    final coords = geometry['coordinates'];
    if (coords is! List) return const [];

    final out = <LatLng>[];
    if (type == 'LineString') {
      for (final pair in coords) {
        final p = _pairToLatLng(pair);
        if (p != null) out.add(p);
      }
    } else if (type == 'MultiLineString') {
      for (final segment in coords) {
        if (segment is! List) continue;
        for (final pair in segment) {
          final p = _pairToLatLng(pair);
          if (p != null) out.add(p);
        }
      }
    }
    return out;
  }

  /// `[lon, lat]` → `LatLng(lat, lon)`. GeoJSON puts longitude first;
  /// flutter_map / latlong2 expect latitude first. This is the only
  /// place that flip lives.
  LatLng? _pairToLatLng(Object? pair) {
    if (pair is! List || pair.length < 2) return null;
    final lon = (pair[0] as num?)?.toDouble();
    final lat = (pair[1] as num?)?.toDouble();
    if (lat == null || lon == null) return null;
    return LatLng(lat, lon);
  }
}
