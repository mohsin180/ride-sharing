import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ride_sharing/provider/authProvider.dart';
import 'package:ride_sharing/provider/availableRidesProvider.dart';
import 'package:ride_sharing/provider/driverActiveRideProvider.dart';
import 'package:ride_sharing/provider/driverFeedProvider.dart';
import 'package:ride_sharing/provider/myRidesProvider.dart';
import 'package:ride_sharing/provider/rideTrackingProvider.dart';
import 'package:ride_sharing/view/driverScreens/driverHomepage.dart';
import 'package:ride_sharing/view/driverScreens/driverProfile.dart';
import 'package:ride_sharing/view/driverScreens/driverRides.dart';
import 'package:ride_sharing/view/driverScreens/driverYourRide.dart';
import 'package:ride_sharing/view/homepage.dart';
import 'package:ride_sharing/view/passengerScreens/profile.dart';
import 'package:ride_sharing/view/rideScreen.dart';
import 'package:ride_sharing/view/yourRide.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';

/// Currently-selected tab index in the bottom navbar. Exposed as a
/// provider so that screens inside the navbar (e.g. the homepage's
/// "See all" pill) can switch tabs without holding a reference to
/// the navbar's state.
class BottomNavIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

final bottomNavIndexProvider =
    NotifierProvider<BottomNavIndexNotifier, int>(BottomNavIndexNotifier.new);

/// Role-aware bottom navigation. The set of screens shown is decided
/// by [selectedRoleProvider] (set on the role-selection screen):
///   - "DRIVER"     → driver screens
///   - "PASSENGER"  → passenger screens (default fallback)
class Bottomnavbar extends ConsumerStatefulWidget {
  const Bottomnavbar({super.key});

  @override
  ConsumerState<Bottomnavbar> createState() => _BottomnavbarState();
}

class _BottomnavbarState extends ConsumerState<Bottomnavbar> {
  static const List<Widget> _passengerScreens = [
    Homepage(),
    Ridescreen(),
    Yourride(),
    Profile(),
  ];

  static const List<Widget> _driverScreens = [
    DriverHomepage(),
    Driverrides(),
    Driveryourride(),
    Driverprofile(),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedRole = ref.watch(selectedRoleProvider);
    final isDriver = selectedRole == "DRIVER";
    final screens = isDriver ? _driverScreens : _passengerScreens;
    final currentIndex = ref.watch(bottomNavIndexProvider);

    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      body: Stack(
        children: [
          IndexedStack(index: currentIndex, children: screens),
          // Keeps the driver broadcasting their GPS for the whole active ride
          // (across every tab), not just while the trip map is on screen.
          if (isDriver) const _DriverLocationBroadcaster(),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor: Colors.transparent,
          labelTextStyle: WidgetStatePropertyAll(
            const TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.w500,
              color: Consonants.boldTextColor,
            ),
          ),
        ),
        child: NavigationBar(
          height: 70,
          selectedIndex: currentIndex,
          animationDuration: const Duration(milliseconds: 300),
          backgroundColor: Consonants.whiteColor,
          onDestinationSelected: (index) {
            ref.read(bottomNavIndexProvider.notifier).select(index);
            // Opening the Ride tab refetches the ride lists so changes made
            // elsewhere show up immediately — e.g. a ride the host cancelled
            // disappears from a co-passenger's "Your Rides", and a cancelled
            // request drops off the driver feed.
            if (index == 1) {
              if (isDriver) {
                ref.invalidate(driverFeedProvider);
              } else {
                ref.invalidate(myRidesProvider);
                ref.invalidate(availableRidesProvider);
              }
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: Consonants.greyColor),
              selectedIcon: Icon(Icons.home, color: Consonants.primaryColor),
              label: "Home",
            ),
            NavigationDestination(
              icon: Icon(
                Icons.directions_car_outlined,
                color: Consonants.greyColor,
              ),
              selectedIcon: Icon(
                Icons.directions_car,
                color: Consonants.primaryColor,
              ),
              label: "Ride",
            ),
            NavigationDestination(
              icon: Icon(Icons.route_outlined, color: Consonants.greyColor),
              selectedIcon: Icon(Icons.route, color: Consonants.primaryColor),
              label: "Your Ride",
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline, color: Consonants.greyColor),
              selectedIcon: Icon(Icons.person, color: Consonants.primaryColor),
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }
}

/// Invisible widget mounted in the driver shell. While the driver has an
/// active ride it keeps the ride's tracking session alive, so their GPS keeps
/// streaming to riders across every tab — not only when the trip map is open.
/// Renders nothing.
class _DriverLocationBroadcaster extends ConsumerWidget {
  const _DriverLocationBroadcaster();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active =
        ref.watch(driverActiveRideProvider).asData?.value ?? const [];
    if (active.isNotEmpty) {
      // Watching keeps the provider (and its socket + GPS stream) alive.
      ref.watch(rideTrackingProvider(RideTrackArgs(active.first.id, 'DRIVER')));
    }
    return const SizedBox.shrink();
  }
}
