import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/providers.dart';

/// The passenger's in-progress trip (ACCEPTED / STARTED) — the ride they
/// host or joined that's now active. Backed by `GET /api/v1/rides/my/active`.
/// Drives the passenger live-tracking screen; empty when not on a trip.
final passengerActiveRideProvider = FutureProvider<List<RideDetails>>((ref) {
  return ref.read(rideServiceProvider).getMyActiveTrip();
});
