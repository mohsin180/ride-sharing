import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/providers.dart';

/// Aggregate ride stats for the authenticated user. Auto-cached;
/// force a refetch with `ref.invalidate(rideStatsProvider)` after a
/// ride completes or when the user pulls-to-refresh on the profile.
final rideStatsProvider = FutureProvider<RideStats>((ref) {
  return ref.read(rideServiceProvider).getMyStats();
});
