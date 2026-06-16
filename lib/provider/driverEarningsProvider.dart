import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/providers.dart';

/// The authenticated driver's earnings summary (today + lifetime) for the
/// home dashboard. Auto-cached; force a refetch with
/// `ref.invalidate(driverEarningsProvider)` after a ride completes.
final driverEarningsProvider = FutureProvider<DriverEarnings>((ref) {
  return ref.read(rideServiceProvider).getDriverEarnings();
});
