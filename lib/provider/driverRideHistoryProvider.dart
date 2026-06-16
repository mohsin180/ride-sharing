import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/providers.dart';

/// Past rides (completed + cancelled) for the authenticated driver.
/// Drives the driver ride-history screen. Auto-cached; force a refetch
/// with `ref.invalidate(driverHistoryProvider)` after a ride completes
/// or from the pull-to-refresh on the history screen itself.
final driverHistoryProvider =
    FutureProvider<List<DriverRideHistory>>((ref) {
  return ref.read(rideServiceProvider).getDriverHistory();
});
