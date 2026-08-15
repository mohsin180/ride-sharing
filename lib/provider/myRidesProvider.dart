import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/providers.dart';

/// Active rides created by (or joined by) the authenticated user. Drives the
/// "Your Rides" tab. Invalidate after the host creates a ride or one of theirs
/// is cancelled so the list stays in sync.
///
/// Self-polls, like [driverFeedProvider] and [rideDetailsProvider], because a
/// co-passenger joining happens on a DIFFERENT device: it changes the trip's
/// distance and therefore everyone's share, and without this the host's card
/// kept showing the fare from before they joined while the ride screen showed
/// the new one.
final myRidesProvider = FutureProvider<List<AvailableRide>>((ref) {
  final timer = Timer(const Duration(seconds: 10), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.read(rideServiceProvider).getMyRides();
});
