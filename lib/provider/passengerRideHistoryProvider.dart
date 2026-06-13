import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/providers.dart';

/// Past rides (completed + cancelled) for the authenticated passenger.
/// Drives the passenger ride-history screen. Auto-cached; force a
/// refetch with `ref.invalidate(passengerRideHistoryProvider)` after a
/// ride completes (so the new row shows up on next view) or from the
/// pull-to-refresh on the history screen itself.
final passengerRideHistoryProvider =
    FutureProvider<List<PassengerRideHistoryItem>>((ref) {
  return ref.read(rideServiceProvider).getPassengerRideHistory();
});
