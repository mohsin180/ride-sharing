import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/providers.dart';

/// The authenticated driver's earnings summary (today + lifetime) for the
/// home dashboard. Auto-cached; force a refetch with
/// `ref.invalidate(driverEarningsProvider)` after a ride completes.
final driverEarningsProvider = FutureProvider<DriverEarnings>((ref) {
  // Self-poll every 20s so earnings refresh after a completed ride even if the
  // driver stays on the home screen. Also invalidated explicitly on complete.
  final timer = Timer(const Duration(seconds: 20), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.read(rideServiceProvider).getDriverEarnings();
});
