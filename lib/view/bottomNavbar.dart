import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
      backgroundColor: Consonants.canvas,
      // The nav floats OVER the content rather than pushing it up — screens
      // reserve Consonants.navClearance at the bottom of their scroll body.
      extendBody: true,
      body: Stack(
        children: [
          // expand, not the default loose fit: a Stack hands non-positioned
          // children loose constraints, so a tab whose content doesn't fill
          // the width shrink-wrapped and drifted left — the "Your Ride"
          // empty state being the visible case.
          IndexedStack(
            index: currentIndex,
            sizing: StackFit.expand,
            children: screens,
          ),
          // Keeps the driver broadcasting their GPS for the whole active ride
          // (across every tab), not just while the trip map is on screen.
          if (isDriver) const _DriverLocationBroadcaster(),
        ],
      ),
      bottomNavigationBar: _FloatingNav(
        currentIndex: currentIndex,
        onSelected: (index) {
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
      ),
    );
  }
}

/// Translucent canvas over a blur, per the system's rule that anything
/// floating above content is never an opaque bar. Active items go indigo with
/// a heavier icon stroke; inactive stay muted.
class _FloatingNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelected;

  const _FloatingNav({required this.currentIndex, required this.onSelected});

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.directions_car_outlined, Icons.directions_car_rounded, 'Ride'),
    (Icons.route_outlined, Icons.route_rounded, 'Your Ride'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xC7F8F9FB),
            border: Border(top: BorderSide(color: Color(0x0D000000))),
          ),
          padding: EdgeInsets.only(top: 12.h, bottom: 20.h),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: _NavItem(
                      icon: currentIndex == i ? _items[i].$2 : _items[i].$1,
                      label: _items[i].$3,
                      active: currentIndex == i,
                      onTap: () => onSelected(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colour = active ? Consonants.indigo : Consonants.textMuted;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 44.h,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 23.sp, color: colour),
            SizedBox(height: 4.h),
            Text(
              label,
              style: AppText.navLabel(color: colour).copyWith(fontSize: 12.sp),
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
