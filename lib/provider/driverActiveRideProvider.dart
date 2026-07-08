import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/providers.dart';

/// The ride(s) the authenticated driver is currently running — ACCEPTED
/// (en route to pickup) or STARTED (trip in progress). Backed by
/// `GET /api/v1/rides/driver/active`.
///
/// Drives the driver's active-trip cockpit: an empty list means the driver
/// isn't on a trip (show the empty state); otherwise seed the cockpit from
/// the first [RideDetails]. Invalidate after accept (`ride enters the
/// list`) or complete (`ride leaves it`) with
/// `ref.invalidate(driverActiveRideProvider)`.
final driverActiveRideProvider = FutureProvider<List<RideDetails>>((ref) {
  // Self-poll every 8s so the driver's active trip appears on its own once the
  // host accepts their offer (and disappears on completion) — no manual
  // refresh or app restart needed.
  final timer = Timer(const Duration(seconds: 8), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.read(rideServiceProvider).getDriverActiveRides();
});
