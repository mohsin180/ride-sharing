import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:ride_sharing/controller/trackingSocket.dart';
import 'package:ride_sharing/model/trackingModels.dart';
import 'package:ride_sharing/provider/providers.dart';
import 'package:ride_sharing/widgets/consonants/apiConsonants.dart';
import 'package:ride_sharing/widgets/consonants/jwtUtils.dart';
import 'package:ride_sharing/widgets/consonants/tokenStorage.dart';

/// Identifies one ride's live-tracking session for a given device role.
/// Same (rideId, role) ⇒ same shared session, so the map and the ETA widgets
/// read one source and the socket/GPS stream opens only once.
class RideTrackArgs {
  final String rideId;
  final String myRole; // "DRIVER" | "PASSENGER"
  const RideTrackArgs(this.rideId, this.myRole);

  @override
  bool operator ==(Object other) =>
      other is RideTrackArgs && other.rideId == rideId && other.myRole == myRole;

  @override
  int get hashCode => Object.hash(rideId, myRole);
}

/// One tracked member's latest known position (the target the map eases toward).
class TrackedMember {
  final LatLng position;
  final String role; // "DRIVER" | "PASSENGER"
  final double? bearing;
  const TrackedMember(this.position, this.role, {this.bearing});
}

/// Live positions for one ride, keyed by userId, plus this device's own id.
class RideTrackingState {
  final Map<String, TrackedMember> members;
  final String? myUserId;
  const RideTrackingState({this.members = const {}, this.myUserId});

  RideTrackingState _with({Map<String, TrackedMember>? members, String? myUserId}) =>
      RideTrackingState(
        members: members ?? this.members,
        myUserId: myUserId ?? this.myUserId,
      );

  /// The driver's live position, if one is being tracked.
  TrackedMember? get driver {
    for (final m in members.values) {
      if (m.role.toUpperCase() == 'DRIVER') return m;
    }
    return null;
  }
}

/// The live-tracking session for one ride. Self-contained: opens a
/// [TrackingSocket], seeds the driver's last-known spot from REST (so a
/// late-opening rider sees the car at once), streams THIS device's GPS to the
/// topic (so everyone else sees us), and folds every incoming position into a
/// [RideTrackingState] pushed onto [stream]. Kept alive as long as something
/// watches the provider — the driver shell holds it open across the whole
/// active ride so the car keeps broadcasting even off the trip map.
class RideTrackingSession {
  final Ref _ref;
  final String rideId;
  final String myRole;

  final StreamController<RideTrackingState> _controller =
      StreamController<RideTrackingState>.broadcast();
  final TrackingSocket _socket = TrackingSocket();
  StreamSubscription<Position>? _gpsSub;
  Timer? _lastKnownTimer;
  DateTime _lastRestPush = DateTime.fromMillisecondsSinceEpoch(0);
  RideTrackingState _state = const RideTrackingState();
  bool _disposed = false;

  RideTrackingSession(this._ref, this.rideId, this.myRole) {
    _start();
  }

  /// Current snapshot first, then every subsequent update.
  Stream<RideTrackingState> get stream async* {
    yield _state;
    yield* _controller.stream;
  }

  Future<void> _start() async {
    final token = await Tokenstorage.getToken();
    final myId = token != null ? JwtUtils.extractUserId(token) : null;
    _emit(_state._with(myUserId: myId));
    await _seedLastDriver();
    await _socket.connect(rideId: rideId, onPosition: _onIncoming);
    _startGps();
    // Riders keep polling the driver's last-known spot so the car shows and
    // moves even when the WebSocket can't connect (REST is the fallback
    // transport both ways — the driver pushes it in _onMyPosition below).
    if (myRole.toUpperCase() != 'DRIVER') {
      _lastKnownTimer = Timer.periodic(
          const Duration(seconds: 5), (_) => _seedLastDriver());
    }
  }

  /// Pull the driver's last-known position up front so the marker is there
  /// immediately, before the next live frame arrives.
  Future<void> _seedLastDriver() async {
    try {
      final json = await _ref
          .read(apiClientProvider)
          .get(Apiconsonants.lastDriverLocationEndpoint(rideId));
      if (json is Map<String, dynamic>) {
        final p = TrackPosition.fromJson(json);
        if (p.userId != _state.myUserId) {
          _upsert(p.userId, p.latLng, p.role, p.bearing);
        }
      }
    } catch (_) {
      // No last-known yet / unreachable — the live stream will fill it in.
    }
  }

  void _startGps() {
    try {
      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 8,
        ),
      ).listen(_onMyPosition, onError: (_) {});
    } catch (_) {
      // Location unavailable — others still show; we just don't broadcast.
    }
  }

  void _onMyPosition(Position pos) {
    final id = _state.myUserId;
    if (id == null) return;
    _upsert(id, LatLng(pos.latitude, pos.longitude), myRole, pos.heading);
    _socket.send(
      rideId,
      lat: pos.latitude,
      lng: pos.longitude,
      role: myRole,
      bearing: pos.heading,
    );
    // Driver also publishes over REST (throttled) so the last-known position
    // stays fresh for riders even when the WebSocket is down — this is what
    // the riders' 5s poll reads.
    if (myRole.toUpperCase() == 'DRIVER' &&
        pos.latitude.isFinite &&
        pos.longitude.isFinite) {
      final now = DateTime.now();
      if (now.difference(_lastRestPush).inSeconds >= 3) {
        _lastRestPush = now;
        _ref
            .read(apiClientProvider)
            .post(Apiconsonants.publishLocationEndpoint(rideId), {
              'role': myRole,
              'lat': pos.latitude,
              'lng': pos.longitude,
              if (pos.heading.isFinite) 'bearing': pos.heading,
            })
            .catchError((_) => null);
      }
    }
  }

  void _onIncoming(TrackPosition p) {
    // Our own position is handled locally from GPS — ignore the echo.
    if (_state.myUserId != null && p.userId == _state.myUserId) return;
    _upsert(p.userId, p.latLng, p.role, p.bearing);
  }

  void _upsert(String userId, LatLng pos, String role, double? bearing) {
    final next = Map<String, TrackedMember>.from(_state.members);
    next[userId] = TrackedMember(pos, role, bearing: bearing);
    _emit(_state._with(members: next));
  }

  void _emit(RideTrackingState s) {
    _state = s;
    if (!_disposed && !_controller.isClosed) _controller.add(s);
  }

  void dispose() {
    _disposed = true;
    _lastKnownTimer?.cancel();
    _gpsSub?.cancel();
    _socket.dispose();
    _controller.close();
  }
}

/// Shared live-tracking session per (ride, role). autoDispose so it tears down
/// when nothing watches it; keep it alive across an active ride by watching it
/// from a long-lived widget (the driver shell) so the driver keeps
/// broadcasting even when not on the trip map.
final rideTrackingProvider = StreamProvider.autoDispose
    .family<RideTrackingState, RideTrackArgs>((ref, args) {
  final session = RideTrackingSession(ref, args.rideId, args.myRole);
  ref.onDispose(session.dispose);
  return session.stream;
});
