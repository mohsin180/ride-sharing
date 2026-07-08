import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/directionsProvider.dart';
import 'package:ride_sharing/services/maps/mapTilesService.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';

/// Orders the shared-ride stops into a single visiting sequence for the map
/// polyline. Greedy nearest-neighbour, starting at the host's pickup and
/// ending at the host's drop, visiting every co-passenger pickup/drop in
/// between — and never a co-passenger's drop before their own pickup. This
/// approximates the "shortest ride" the user wants without a full
/// pickup-delivery solver (overkill for a map preview).
///
/// With no co-passengers this is simply [hostPickup, hostDrop] → A→B.
List<RideStop> orderRouteStops(List<RideStop> stops, String hostId) {
  if (stops.length <= 2) return List.of(stops);

  RideStop? start; // host pickup
  RideStop? end; // host drop
  final pickups = <RideStop>[]; // co-passenger pickups
  final drops = <RideStop>[]; // co-passenger drops
  for (final s in stops) {
    if (s.ownerId == hostId && s.isPickup) {
      start = s;
    } else if (s.ownerId == hostId && !s.isPickup) {
      end = s;
    } else if (s.isPickup) {
      pickups.add(s);
    } else {
      drops.add(s);
    }
  }
  // Defensive fallback if the host stops aren't present as expected.
  start ??= stops.first;
  end ??= stops.last;

  const distance = Distance();
  // Visit a list of stops nearest-first starting from `from`.
  List<RideStop> chainFrom(RideStop from, List<RideStop> items) {
    final out = <RideStop>[];
    final remaining = List.of(items);
    var current = from;
    while (remaining.isNotEmpty) {
      remaining.sort((a, b) => distance(
            LatLng(current.lat, current.lng),
            LatLng(a.lat, a.lng),
          ).compareTo(distance(
            LatLng(current.lat, current.lng),
            LatLng(b.lat, b.lng),
          )));
      final next = remaining.removeAt(0);
      out.add(next);
      current = next;
    }
    return out;
  }

  // A clean stop-by-stop line: pick everyone up first (host, then the
  // co-passengers nearest-first), then drop everyone off, host last —
  // A → B → C → D → E → F, never jumping back and forth.
  final orderedPickups = chainFrom(start, pickups);
  final lastPickup = orderedPickups.isNotEmpty ? orderedPickups.last : start;
  final orderedDrops = chainFrom(lastPickup, drops);
  return [start, ...orderedPickups, ...orderedDrops, end];
}

/// Draws the full shared-ride route on a map: every pickup/drop as a
/// labelled marker (A, B, C…) in shortest-path order, joined by a road
/// polyline from the routing service. Replaces the old text route cards.
class RideRouteMap extends ConsumerWidget {
  final List<RideStop> stops;
  final String hostId;

  /// Used to centre the map before/if routing is unavailable.
  final LatLng? fallbackCenter;

  const RideRouteMap({
    super.key,
    required this.stops,
    required this.hostId,
    this.fallbackCenter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordered = orderRouteStops(stops, hostId);
    final waypoints = [
      for (final s in ordered) LatLng(s.lat, s.lng),
    ];

    if (waypoints.isEmpty) {
      // Nothing to draw yet — plain map centred on the fallback.
      return _map(
        center: fallbackCenter ?? const LatLng(31.5204, 74.3587),
        zoom: 13,
        children: const [],
      );
    }

    // The road route through all stops (straight lines as a fallback while
    // it loads or if routing fails, so the legs are always visible).
    final routeAsync = waypoints.length >= 2
        ? ref.watch(routeThroughProvider(RouteThroughRequest(waypoints)))
        : null;
    final roadPoints = routeAsync?.maybeWhen(
      data: (r) => r.points,
      orElse: () => null,
    );
    final linePoints = (roadPoints != null && roadPoints.isNotEmpty)
        ? roadPoints
        : waypoints;

    return _map(
      cameraFit: waypoints.length >= 2
          ? CameraFit.coordinates(
              coordinates: waypoints,
              padding: EdgeInsets.all(48.w),
            )
          : null,
      center: waypoints.first,
      zoom: 14,
      children: [
        PolylineLayer(
          polylines: [
            Polyline(
              points: linePoints,
              strokeWidth: 4.5,
              color: Consonants.primaryColor,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            for (var i = 0; i < ordered.length; i++)
              _stopMarker(ordered[i], i),
          ],
        ),
      ],
    );
  }

  Marker _stopMarker(RideStop stop, int index) {
    final letter = String.fromCharCode(65 + index); // A, B, C…
    final color = stop.isPickup
        ? Consonants.primaryColor
        : const Color(0xffEF4444);
    return Marker(
      point: LatLng(stop.lat, stop.lng),
      width: 30.w,
      height: 30.w,
      alignment: Alignment.center,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          letter,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12.sp,
            fontWeight: FontWeight.w800,
            fontFamily: Consonants.fontFamily,
          ),
        ),
      ),
    );
  }

  Widget _map({
    LatLng? center,
    double zoom = 13,
    CameraFit? cameraFit,
    required List<Widget> children,
  }) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: center ?? const LatLng(31.5204, 74.3587),
        initialZoom: zoom,
        initialCameraFit: cameraFit,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom |
              InteractiveFlag.drag |
              InteractiveFlag.doubleTapZoom,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: MapTilesService.tileUrl,
          subdomains: MapTilesService.subdomains,
          userAgentPackageName: MapTilesService.userAgentPackageName,
          tileProvider: CancellableNetworkTileProvider(),
        ),
        ...children,
      ],
    );
  }
}
