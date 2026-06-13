import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:ride_sharing/controller/trackingSocket.dart';
import 'package:ride_sharing/model/trackingModels.dart';
import 'package:ride_sharing/provider/directionsProvider.dart';
import 'package:ride_sharing/services/maps/mapTilesService.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/jwtUtils.dart';
import 'package:ride_sharing/widgets/consonants/tokenStorage.dart';

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

  const LiveTrackingMap({
    super.key,
    required this.rideId,
    required this.pickup,
    required this.drop,
    required this.myRole,
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
  final TrackingSocket _socket = TrackingSocket();
  StreamSubscription<Position>? _gpsSub;
  Ticker? _ticker;

  final Map<String, _Track> _tracks = {};
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _init();
  }

  Future<void> _init() async {
    final token = await Tokenstorage.getToken();
    _myUserId = token != null ? JwtUtils.extractUserId(token) : null;
    await _socket.connect(rideId: widget.rideId, onPosition: _onIncoming);
    _startGps();
  }

  void _startGps() {
    try {
      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 8, // metres of movement before a new fix
        ),
      ).listen(_onMyPosition, onError: (_) {});
    } catch (_) {
      // Location stream unavailable (permissions/services) — others still
      // show; this device just won't broadcast its own position.
    }
  }

  void _onMyPosition(Position pos) {
    final id = _myUserId;
    if (id == null) return;
    final here = LatLng(pos.latitude, pos.longitude);
    // Show our own marker immediately (don't wait for the server echo).
    final existing = _tracks[id];
    if (existing == null) {
      _tracks[id] = _Track(here, here, widget.myRole);
      if (mounted) setState(() {});
    } else {
      existing.target = here;
      existing.role = widget.myRole;
    }
    _socket.send(
      widget.rideId,
      lat: here.latitude,
      lng: here.longitude,
      role: widget.myRole,
      bearing: pos.heading,
    );
  }

  void _onIncoming(TrackPosition p) {
    if (!mounted) return;
    // Our own position is handled locally from GPS — ignore the echo.
    if (_myUserId != null && p.userId == _myUserId) return;
    final existing = _tracks[p.userId];
    if (existing == null) {
      // New member: appear instantly, then animate from here on.
      setState(() => _tracks[p.userId] = _Track(p.latLng, p.latLng, p.role));
    } else {
      existing.target = p.latLng;
      existing.role = p.role;
    }
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
    _gpsSub?.cancel();
    _ticker?.dispose();
    _socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(directionsProvider(
      DirectionsRequest(origin: widget.pickup, destination: widget.drop),
    ));
    final routePoints = async.maybeWhen(
      data: (r) => r.points,
      orElse: () => <LatLng>[widget.pickup, widget.drop],
    );

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
            Polyline(
              points: routePoints,
              color: Consonants.primaryColor,
              strokeWidth: 4,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
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
