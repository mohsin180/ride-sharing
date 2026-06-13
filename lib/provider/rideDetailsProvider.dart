import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/providers.dart';

/// Full details for one ride, keyed by ride id. Powers the viewRequest
/// screen — host, route, fare, co-passengers.
///
/// Family-keyed so opening a different ride doesn't invalidate the
/// cache for the one you came from (handy for back/forward nav). Force
/// a refetch with `ref.invalidate(rideDetailsProvider(id))` after the
/// current user joins/cancels so the seats + co-passengers update.
final rideDetailsProvider =
    FutureProvider.family<RideDetails, String>((ref, id) {
  return ref.read(rideServiceProvider).getRideDetails(id);
});
