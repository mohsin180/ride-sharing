import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/providers.dart';
import 'package:ride_sharing/provider/rideRequestProvider.dart';

/// Available rides the authenticated passenger can join.
///
/// The search is driven by [rideRequestProvider]'s pickup coordinate
/// — i.e. whatever the user typed (and picked from autocomplete) in
/// the Available Rides search form. Backend computes each ride's
/// distance from that point so the screen can apply a 5 km cap.
///
/// Uses `ref.read` (not `watch`) on the pickup so refetches are
/// triggered explicitly via `ref.invalidate(availableRidesProvider)`
/// — typically on Save tap — rather than firing on every keystroke.
///
/// Returns an empty list when the user hasn't picked a pickup yet,
/// which lets the screen render a "do a search first" prompt instead
/// of an unbounded global list.
final availableRidesProvider =
    FutureProvider<List<AvailableRide>>((ref) async {
  final req = ref.read(rideRequestProvider);
  final pickup = req.pickupLatLng;
  if (pickup == null) return const [];
  // Pass the destination too when set, so the backend keeps only rides going
  // the same way (route overlap) and ranks them best-match first.
  final drop = req.dropLatLng;
  return ref.read(rideServiceProvider).getAvailableRides(
        lat: pickup.latitude,
        lng: pickup.longitude,
        dropLat: drop?.latitude,
        dropLng: drop?.longitude,
      );
});
