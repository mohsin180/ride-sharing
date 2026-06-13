import 'package:latlong2/latlong.dart';

/// Bounding box around a polyline, used for "fit-the-route" camera
/// moves. Mirrors what `LatLngBounds` from google_maps_flutter offered
/// but in a provider-agnostic shape.
class LatLngBoundsLite {
  final LatLng southWest;
  final LatLng northEast;

  const LatLngBoundsLite({
    required this.southWest,
    required this.northEast,
  });

  /// Computes the tight bounding box containing every point. Returns
  /// null for an empty list — callers should skip the camera fit when
  /// there's nothing to frame.
  static LatLngBoundsLite? fromPoints(List<LatLng> points) {
    if (points.isEmpty) return null;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    return LatLngBoundsLite(
      southWest: LatLng(minLat, minLng),
      northEast: LatLng(maxLat, maxLng),
    );
  }
}

/// Decoded route returned by [RoutingService.route]. Replaces the old
/// `DirectionsResult` wrapper around Google's Directions API response.
///
/// `points` is already in lat/lng order (Geoapify returns lon/lat in
/// GeoJSON; the service flips it for us so the rest of the app never
/// has to think about it).
class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final int durationSeconds;
  final LatLngBoundsLite? bounds;

  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.bounds,
  });

  /// Whole kilometres rounded for display ("12 km"). The booking sheet
  /// and the live-distance strip both wanted this format.
  String get distanceLabel {
    final km = distanceMeters / 1000;
    if (km < 1) return '${distanceMeters.round()} m';
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }

  /// Human-friendly ETA — "8 min" / "1 h 12 min".
  String get etaLabel {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    return rem == 0 ? '$hours h' : '$hours h $rem min';
  }
}
