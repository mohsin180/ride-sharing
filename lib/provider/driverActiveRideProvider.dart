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
  return ref.read(rideServiceProvider).getDriverActiveRides();
});
