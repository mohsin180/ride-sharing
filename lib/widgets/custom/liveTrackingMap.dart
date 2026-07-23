import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/directionsProvider.dart';
import 'package:ride_sharing/provider/rideTrackingProvider.dart';
import 'package:ride_sharing/widgets/custom/rideRouteMap.dart' show orderRouteStops;
import 'package:ride_sharing/services/maps/mapTilesService.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';

/// Live tracking map shared by the driver and passenger trip screens.
///
/// Self-contained: it opens a [TrackingSocket] for the ride, streams this
/// device's GPS to it (so others see you), and renders an animated marker
/// for every member — a **car** for the driver, a **person** for each
/// passenger — that glides smoothly toward each new position. Also draws
/// the pickup → drop route. Drop it in place of a static map and pass the
/// ride id, pickup/drop, and your own role.
class LiveTrackingMap extends ConsumerStatefulWidget {
  final String rideId;
  final LatLng pickup;
  final LatLng drop;

  /// This device's role — "DRIVER" or "PASSENGER" — used to style your own
  /// marker and to tag the positions you publish.
  final String myRole;

  /// All stops on the shared ride (host + each joined co-passenger's
  /// pickup/drop). When 2+ are given, the map draws the FULL route through
  /// every stop in shortest-path order (A→B→C→D) with labelled markers,
  /// instead of just a single host pickup→drop line. Empty ⇒ fall back to
  /// the plain pickup/drop route.
  final List<RideStop> stops;

  /// Host user id, used to anchor the shortest-path ordering at the host's
  /// pickup (start) and drop (end).
  final String hostId;

  /// When true and no live driver fix is available, the route-consume anchor
  /// falls back to THIS device's own GPS — used by rider screens once the
  /// trip is in transit (the rider is travelling in the same car), so the
  /// covered path keeps disappearing even if the driver's feed drops out.
  final bool consumeWithMyPosition;

  const LiveTrackingMap({
    super.key,
    required this.rideId,
    required this.pickup,
    required this.drop,
    required this.myRole,
    this.stops = const [],
    this.hostId = '',
    this.consumeWithMyPosition = false,
  });

  @override
  ConsumerState<LiveTrackingMap> createState() => _LiveTrackingMapState();
}

/// One tracked member: where their marker is drawn now (`displayed`) eased
/// toward where they actually are (`target`).
class _Track {
  LatLng displayed;
  LatLng target;
  String role;
  _Track(this.displayed, this.target, this.role);
}

class _LiveTrackingMapState extends ConsumerState<LiveTrackingMap>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;

  final Map<String, _Track> _tracks = {};
  String? _myUserId;

  // ─── Route-consume progress ─────────────────────────────
  // As the driver travels the route, the covered part is trimmed away so
  // only the remaining path stays drawn (both driver + rider screens).
  /// Driver counts as ON the route when within this many metres of it.
  static const double _onRouteThresholdM = 100.0;
  final Distance _geo = const Distance();

  /// Index of the route point the driver has reached — only ever advances,
  /// so a route that loops near itself can't snap the car backwards.
  int _routeProgress = 0;

  /// True once the driver's live position is riding along the route.
  bool _onRoute = false;

  /// Cheap identity of the route we're tracking progress on; when the route
  /// itself changes (refetch / stops changed), progress restarts.
  int _routeSig = 0;

  /// Advance [_routeProgress] to the route point nearest the driver
  /// (forward-only), and flag whether they're actually on the route.
  void _updateRouteProgress(List<LatLng> route, LatLng driverPos) {
    final sig = route.length ^ route.first.hashCode ^ route.last.hashCode;
    if (sig != _routeSig) {
      _routeSig = sig;
      _routeProgress = 0;
      _onRoute = false;
    }
    int best = _routeProgress;
    double bestD = double.infinity;
    for (int i = _routeProgress; i < route.length; i++) {
      final d = _geo.as(LengthUnit.Meter, route[i], driverPos);
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    if (bestD <= _onRouteThresholdM) {
      _routeProgress = best;
      _onRoute = true;
    } else {
      // Off the route (heading to the first pickup, GPS drift, a detour) —
      // keep the progress we already made so covered path never reappears.
      _onRoute = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  /// Fold the shared tracking state (socket + GPS live in the provider) into
  /// our local eased markers. New members appear instantly; existing ones get
  /// a fresh target the ticker glides toward.
  void _syncFrom(RideTrackingState tracking) {
    _myUserId = tracking.myUserId ?? _myUserId;
    tracking.members.forEach((userId, m) {
      final existing = _tracks[userId];
      if (existing == null) {
        _tracks[userId] = _Track(m.position, m.position, m.role);
      } else {
        existing.target = m.position;
        existing.role = m.role;
      }
    });
  }

  /// Eases every marker toward its target a little each frame for smooth
  /// motion. Only rebuilds when something actually moved.
  void _onTick(Duration _) {
    bool moved = false;
    for (final t in _tracks.values) {
      if (t.displayed == t.target) continue;
      final next = LatLng(
        t.displayed.latitude + (t.target.latitude - t.displayed.latitude) * 0.18,
        t.displayed.longitude +
            (t.target.longitude - t.displayed.longitude) * 0.18,
      );
      // Snap when close enough so it settles instead of crawling forever.
      final close = (t.target.latitude - next.latitude).abs() < 1e-6 &&
          (t.target.longitude - next.longitude).abs() < 1e-6;
      t.displayed = close ? t.target : next;
      moved = true;
    }
    if (moved && mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Live positions come from the shared tracking session (one socket + GPS
    // stream per ride/role); fold them into our eased markers.
    final tracking = ref
            .watch(rideTrackingProvider(
                RideTrackArgs(widget.rideId, widget.myRole)))
            .asData
            ?.value ??
        const RideTrackingState();
    _syncFrom(tracking);

    // Full multi-stop route (host + co-passengers) in shortest-path order when
    // we have the stops; otherwise a plain pickup→drop line.
    final ordered = widget.stops.length >= 2
        ? orderRouteStops(widget.stops, widget.hostId)
        : const <RideStop>[];
    final useMulti = ordered.length >= 2;

    final List<LatLng> routePoints;
    if (useMulti) {
      final waypoints = [for (final s in ordered) LatLng(s.lat, s.lng)];
      routePoints = ref
          .watch(routeThroughProvider(RouteThroughRequest(waypoints)))
          .maybeWhen(
            data: (r) => r.points.isNotEmpty ? r.points : waypoints,
            orElse: () => waypoints,
          );
    } else {
      routePoints = ref
          .watch(directionsProvider(
            DirectionsRequest(origin: widget.pickup, destination: widget.drop),
          ))
          .maybeWhen(
            data: (r) => r.points,
            orElse: () => <LatLng>[widget.pickup, widget.drop],
          );
    }

    // Consume the route as the car travels: trim everything already covered
    // so only the REMAINING path stays drawn, anchored at the car. Shared
    // widget ⇒ the effect shows on driver AND rider screens. The consuming
    // position is the car when we have it; on rider screens mid-trip it
    // falls back to the rider's own GPS (they travel in the same vehicle).
    final driver = tracking.driver;
    LatLng? consumePos = driver?.position;
    if (consumePos == null &&
        widget.consumeWithMyPosition &&
        _myUserId != null) {
      consumePos = tracking.members[_myUserId]?.position;
    }
    List<LatLng> displayRoute = routePoints;
    if (consumePos != null && routePoints.length >= 2) {
      _updateRouteProgress(routePoints, consumePos);
      if (_onRoute || _routeProgress > 0) {
        final tail = _routeProgress + 1 < routePoints.length
            ? routePoints.sublist(_routeProgress + 1)
            : const <LatLng>[];
        // Anchor the remaining path at the live position while on-route;
        // during an off-route wobble, anchor at the last reached point.
        final anchor = _onRoute ? consumePos : routePoints[_routeProgress];
        displayRoute = <LatLng>[anchor, ...tail];
      }
    }

    // Approach leg: from the driver's live position to the first pickup, so
    // the driver AND every rider can watch the car closing in on the route.
    // Hidden once the car is ON the route — from then on the (shrinking)
    // route itself is the guidance.
    List<LatLng> approachPoints = const [];
    if (driver != null && !_onRoute) {
      final firstStop = useMulti
          ? LatLng(ordered.first.lat, ordered.first.lng)
          : widget.pickup;
      // Round the origin (~110 m) so the route only refetches when the car
      // has meaningfully moved, not on every GPS tick.
      final origin = LatLng(
          (driver.position.latitude * 1000).roundToDouble() / 1000,
          (driver.position.longitude * 1000).roundToDouble() / 1000);
      approachPoints = ref
          .watch(directionsProvider(
              DirectionsRequest(origin: origin, destination: firstStop)))
          .maybeWhen(
            data: (r) => r.points.isNotEmpty
                ? r.points
                : <LatLng>[driver.position, firstStop],
            orElse: () => <LatLng>[driver.position, firstStop],
          );
    }

    return FlutterMap(
      options: MapOptions(
        initialCenter: _initialCenter(),
        initialZoom: 14,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom |
              InteractiveFlag.drag |
              InteractiveFlag.doubleTapZoom |
              InteractiveFlag.flingAnimation,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: MapTilesService.tileUrl,
          subdomains: MapTilesService.subdomains,
          userAgentPackageName: MapTilesService.userAgentPackageName,
          tileProvider: CancellableNetworkTileProvider(),
        ),
        PolylineLayer(
          polylines: [
            // Remaining trip route — shrinks behind the car as it travels.
            if (displayRoute.length >= 2)
              Polyline(
                points: displayRoute,
                color: Consonants.primaryColor,
                strokeWidth: 4,
              ),
            // Driver's approach to the first pickup — green, matching the
            // car marker, so it reads as "the car is on its way here".
            if (approachPoints.length >= 2)
              Polyline(
                points: approachPoints,
                color: const Color(0xff10B981),
                strokeWidth: 3.5,
              ),
          ],
        ),
        MarkerLayer(
          markers: [
            // Labelled stop markers A,B,C… along the ordered multi-stop route;
            // fall back to plain pickup/drop pins when there are no stops.
            if (useMulti)
              for (int i = 0; i < ordered.length; i++)
                Marker(
                  point: LatLng(ordered[i].lat, ordered[i].lng),
                  width: 30,
                  height: 30,
                  child: _StopMarker(
                    letter: String.fromCharCode(65 + i),
                    isPickup: ordered[i].isPickup,
                  ),
                )
            else ...[
              Marker(
                point: widget.pickup,
                width: 26,
                height: 26,
                child: const _PinMarker(
                  color: Color(0xff2196F3),
                  icon: Icons.my_location_rounded,
                ),
              ),
              Marker(
                point: widget.drop,
                width: 26,
                height: 26,
                child: const _PinMarker(
                  color: Color(0xffEF4444),
                  icon: Icons.location_on_rounded,
                ),
              ),
            ],
            for (final entry in _tracks.entries)
              Marker(
                point: entry.value.displayed,
                width: 42,
                height: 42,
                child: _LiveMarker(
                  isDriver: entry.value.role.toUpperCase() == 'DRIVER',
                  isMe: entry.key == _myUserId,
                ),
              ),
          ],
        ),
        const RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
            TextSourceAttribution('CARTO'),
          ],
        ),
      ],
    );
  }

  /// Centre on the live driver if we have one, otherwise the route midpoint.
  LatLng _initialCenter() {
    for (final t in _tracks.values) {
      if (t.role.toUpperCase() == 'DRIVER') return t.displayed;
    }
    return LatLng(
      (widget.pickup.latitude + widget.drop.latitude) / 2,
      (widget.pickup.longitude + widget.drop.longitude) / 2,
    );
  }
}

/// Static pickup / drop pin (small circle + icon).
class _PinMarker extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _PinMarker({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 13),
    );
  }
}

/// A labelled stop on the multi-stop route — a lettered circle (A, B, C…),
/// blue for a pickup and red for a drop-off.
class _StopMarker extends StatelessWidget {
  final String letter;
  final bool isPickup;
  const _StopMarker({required this.letter, required this.isPickup});

  @override
  Widget build(BuildContext context) {
    final color = isPickup ? Consonants.primaryColor : const Color(0xffEF4444);
    return Container(
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
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// A live member marker: a car for the driver, a person for a passenger.
/// "You" gets a thicker ring so you can spot yourself.
class _LiveMarker extends StatelessWidget {
  final bool isDriver;
  final bool isMe;
  const _LiveMarker({required this.isDriver, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final color = isDriver ? const Color(0xff10B981) : const Color(0xff7C3AED);
    final icon =
        isDriver ? Icons.directions_car_filled_rounded : Icons.person_rounded;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: isMe ? 3 : 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
