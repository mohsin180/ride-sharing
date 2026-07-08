import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/providers.dart';

/// The passenger's in-progress trip (ACCEPTED / ARRIVED / STARTED) — the
/// ride they host or joined that's now active. Backed by
/// `GET /api/v1/rides/my/active`. Drives the passenger live-tracking screen
/// and the status banner; empty when not on a trip.
final passengerActiveRideProvider = FutureProvider<List<RideDetails>>((ref) {
  // Self-poll every 4s so status changes the driver makes (arrived, started,
  // completed) surface on the passenger's screen quickly, not after a long
  // lag. Kept off the socket for now — this is the source-of-truth sync.
  final timer = Timer(const Duration(seconds: 4), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.read(rideServiceProvider).getMyActiveTrip();
});
