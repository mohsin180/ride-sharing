import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/mapProvider.dart';
import 'package:ride_sharing/provider/providers.dart';

/// Fresh ride requests the authenticated driver can claim. Backed by
/// `GET /api/v1/rides/driver/feed`, ranked by proximity to the driver's
/// current location (PostGIS) and bounded to a nearby radius when a GPS
/// fix is available.
///
/// The driver-rides screen only watches this while the driver is online
/// (see `driverOnlineProvider`); offline it shows a placeholder and never
/// fetches. Force a refresh — after accept/decline or pull-to-refresh —
/// with `ref.invalidate(driverFeedProvider)`.
final driverFeedProvider = FutureProvider<List<AvailableRide>>((ref) async {
  // Self-poll every 12s so newly-published rides appear (and taken ones drop)
  // while the driver watches the feed — no pull-to-refresh needed.
  final timer = Timer(const Duration(seconds: 12), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  // Resolve the driver's current location to rank/bound the feed. If it can't
  // be obtained (GPS off / permission denied), fall back to the full pending
  // feed rather than showing nothing.
  LatLng? loc;
  try {
    loc = await ref.watch(currentLocationProvider.future);
  } catch (_) {
    loc = null;
  }
  return ref.read(rideServiceProvider).getDriverFeed(
        lat: loc?.latitude,
        lng: loc?.longitude,
      );
});
