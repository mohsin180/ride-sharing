import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ride_sharing/provider/authProvider.dart' show selectedRoleProvider;
import 'package:ride_sharing/provider/availableRidesProvider.dart';
import 'package:ride_sharing/provider/mapProvider.dart';
import 'package:ride_sharing/provider/myRidesProvider.dart';
import 'package:ride_sharing/provider/passengerRideHistoryProvider.dart';
import 'package:ride_sharing/provider/profileProvider.dart';
import 'package:ride_sharing/provider/rideCreationProvider.dart';
import 'package:ride_sharing/provider/rideRequestProvider.dart';
import 'package:ride_sharing/provider/rideStatsProvider.dart';
import 'package:ride_sharing/view/bottomNavbar.dart' show bottomNavIndexProvider;

/// Wipes every user-scoped Riverpod cache so the next session starts
/// clean. Without this, cached data from a previous account (profile,
/// rides, stats, search criteria) bleeds into a freshly-logged-in user
/// — e.g. logging out of User A and signing up as User B would show
/// User A's profile in the navbar until something forced a refetch.
///
/// Called from:
///   - the logout flow, right after `authControllerProvider.logout()`
///   - the post-login routing guard, so even a session that bypassed
///     logout (force-quit, deep link, etc.) gets fresh data
///
/// Does NOT touch auth state itself — that's owned by
/// `authControllerProvider` and reset by its own `logout()` / new
/// `loginProvider` call.
void clearUserSession(WidgetRef ref) {
  // Profile + role
  ref.invalidate(passengerProfileProvider);
  ref.invalidate(driverProfileProvider);
  ref.invalidate(selectedRoleProvider);

  // Ride state
  ref.invalidate(availableRidesProvider);
  ref.invalidate(myRidesProvider);
  ref.invalidate(passengerRideHistoryProvider);
  ref.invalidate(rideStatsProvider);
  ref.invalidate(rideRequestProvider);
  ref.invalidate(rideCreationProvider);

  // Map / location state
  ref.invalidate(pickupLocationProvider);
  ref.invalidate(pickupAddressProvider);

  // UI navigation state — drop back to the Home tab on next entry.
  ref.invalidate(bottomNavIndexProvider);
}
