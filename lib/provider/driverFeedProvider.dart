import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/providers.dart';

/// Fresh ride requests the authenticated driver can claim. Backed by
/// `GET /api/v1/rides/driver/feed`.
///
/// The driver-rides screen only watches this while the driver is online
/// (see `driverOnlineProvider`); offline it shows a placeholder and never
/// fetches. Force a refresh — after accept/decline or pull-to-refresh —
/// with `ref.invalidate(driverFeedProvider)`.
final driverFeedProvider = FutureProvider<List<AvailableRide>>((ref) {
  return ref.read(rideServiceProvider).getDriverFeed();
});
