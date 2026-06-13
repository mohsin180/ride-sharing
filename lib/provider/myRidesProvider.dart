import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/providers.dart';

/// Active rides created by the authenticated user. Drives the "Your
/// Rides" tab on the rides screen. Auto-cached; invalidate after the
/// host creates a new ride or one of theirs is cancelled so the list
/// stays in sync.
final myRidesProvider = FutureProvider<List<AvailableRide>>((ref) {
  return ref.read(rideServiceProvider).getMyRides();
});
