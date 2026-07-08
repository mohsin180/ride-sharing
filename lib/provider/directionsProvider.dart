import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:ride_sharing/model/routeModels.dart';
import 'package:ride_sharing/services/maps/routingService.dart';

/// One end-to-end route between two coords. Same shape callers used
/// pre-migration — `distanceKm` and `durationMinutes` getters preserved
/// so [_LiveDistanceStrip] and friends don't need rewiring.
///
/// Internally backed by [RouteResult] from [RoutingService] (Geoapify),
/// not the Google Directions API. The encoded-polyline field that used
/// to live here is gone: Geoapify returns GeoJSON directly so there's
/// no encoded string to decode.
class DirectionsResult {
  /// Trip distance in metres. Now a double (was an int) — Geoapify
  /// returns sub-metre precision; we don't round here so consumers can
  /// format however they want.
  final double distanceMeters;

  /// Trip duration in seconds.
  final int durationSeconds;

  /// Decoded route points, ready for `flutter_map`'s `PolylineLayer`.
  /// Type is now `latlong2.LatLng` (was `google_maps_flutter.LatLng`).
  /// Screens still on GoogleMap convert at the call site until they
  /// migrate in the final cleanup stage.
  final List<LatLng> points;

  /// Bounding box that encloses the whole route — useful for
  /// "fit-the-route" camera moves on flutter_map.
  final LatLngBoundsLite? bounds;

  const DirectionsResult({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.points,
    required this.bounds,
  });

  double get distanceKm => distanceMeters / 1000.0;
  int get durationMinutes => (durationSeconds / 60).round();
}

/// Args for [directionsProvider]. Equality matters because Riverpod
/// uses it to cache results — same origin/destination = same future.
/// LatLng now resolves to `latlong2.LatLng` post-migration; legacy
/// callers that still hold `google_maps_flutter.LatLng` instances
/// rebuild a latlong2 LatLng inline (they share the same `.latitude`
/// / `.longitude` getters so the conversion is one line).
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

/// Args for [routeThroughProvider] — an ordered list of waypoints. Value
/// equality over the coords so Riverpod caches identical routes (and the
/// map doesn't refetch on every rebuild).
class RouteThroughRequest {
  final List<LatLng> waypoints;
  const RouteThroughRequest(this.waypoints);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RouteThroughRequest) return false;
    if (other.waypoints.length != waypoints.length) return false;
    for (var i = 0; i < waypoints.length; i++) {
      if (waypoints[i].latitude != other.waypoints[i].latitude ||
          waypoints[i].longitude != other.waypoints[i].longitude) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(
        waypoints.map((p) => Object.hash(p.latitude, p.longitude)),
      );
}

/// Singleton [RoutingService]. One HTTP client lives for the app's
/// lifetime; closed automatically on container dispose.
final routingServiceProvider = Provider<RoutingService>((ref) {
  final service = RoutingService();
  ref.onDispose(service.dispose);
  return service;
});

/// Computes a driving route between two points via Geoapify. Throws if
/// the key isn't set, the network errors out, or the API returns
/// 4xx/5xx; consumers render the error via `AsyncValue.when(error: …)`.
final directionsProvider =
    FutureProvider.family<DirectionsResult, DirectionsRequest>(
  (ref, req) async {
    final service = ref.read(routingServiceProvider);
    final route = await service.route(from: req.origin, to: req.destination);
    return DirectionsResult(
      distanceMeters: route.distanceMeters,
      durationSeconds: route.durationSeconds,
      points: route.points,
      bounds: route.bounds,
    );
  },
);

/// Multi-stop route through an ordered list of waypoints (the shared-ride
/// map polyline: host pickup → … → host drop). autoDispose so closing the
/// ride screen drops the cache. Returns one [DirectionsResult] whose
/// `points` span the whole trip.
final routeThroughProvider =
    FutureProvider.autoDispose.family<DirectionsResult, RouteThroughRequest>(
  (ref, req) async {
    final service = ref.read(routingServiceProvider);
    final route = await service.routeThrough(req.waypoints);
    return DirectionsResult(
      distanceMeters: route.distanceMeters,
      durationSeconds: route.durationSeconds,
      points: route.points,
      bounds: route.bounds,
    );
  },
);
