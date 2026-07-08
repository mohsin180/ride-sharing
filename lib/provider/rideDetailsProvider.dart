import 'dart:async';

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
///
/// `autoDispose` so the cache is dropped once the ride screen is closed:
/// reopening it refetches fresh details. While the screen stays mounted/in
/// the nav stack the provider is kept alive, so back/forward nav reuses it.
///
/// Also self-polls every 6s while a screen is watching it: the host's
/// accept/decline happens on a DIFFERENT device, so the co-passenger's open
/// ride screen has no in-app signal. Polling flips it to "joined" (seats +
/// co-passengers + CTA update) within a few seconds without a manual reload.
/// autoDispose means the timer stops as soon as the screen closes.
final rideDetailsProvider =
    FutureProvider.autoDispose.family<RideDetails, String>((ref, id) {
  final timer = Timer(const Duration(seconds: 6), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.read(rideServiceProvider).getRideDetails(id);
});
