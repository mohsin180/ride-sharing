import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ride_sharing/provider/directionsProvider.dart';
import 'package:ride_sharing/provider/mapProvider.dart' show kMinimalMapStyle;
import 'package:ride_sharing/view/bottomNavbar.dart' show bottomNavIndexProvider;
import 'package:ride_sharing/view/driverScreens/driverViewDetails.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

/// Index of the "Your Ride" tab inside [bottomNavIndexProvider]. Used to
/// lazily mount the [GoogleMap] only after the user has visited this tab
/// at least once — see `_DriveryourrideState._mapMounted`.
const int _kYourRideTabIndex = 2;

/// Driver "Your Ride" tab — the active-trip cockpit.
///
/// Shown while a shared ride is in progress: live map up top, a dynamic
/// status banner, a focus card for the next passenger, and a sticky CTA
/// that morphs through pickup/drop phases. When there's no active ride
/// the tab falls back to a clean empty state with a shortcut to Rides.
///
/// State is local for now (`_demoActive`, `_currentIndex`, `_phase`) so
/// the demo flow runs end-to-end. Lift into a provider when the rides
/// API lands so other tabs can react to the in-progress trip.
class Driveryourride extends StatefulWidget {
  const Driveryourride({super.key});

  @override
  State<Driveryourride> createState() => _DriveryourrideState();
}

enum _RidePhase {
  headingToPickup,
  arrivedAtPickup,
  inTransitNextPickup,
  inTransitDropoff,
  lastDropoff,
}

class _DriveryourrideState extends State<Driveryourride>
    with TickerProviderStateMixin {
  // Hardcoded route in the Lahore area — kept consistent with kDefaultLatLng
  // so the map style and zoom feel right.
  static const _pickup = LatLng(31.5142, 74.3625);
  static const _drop = LatLng(31.5290, 74.3500);
  static const _driver = LatLng(31.5180, 74.3590);
  static const _via1 = LatLng(31.5210, 74.3585);
  static const _via2 = LatLng(31.5260, 74.3540);

  late List<Passenger> _passengers;
  int _currentIndex = 0;
  _RidePhase _phase = _RidePhase.headingToPickup;

  bool _demoActive = true;

  /// True once the user has selected the "Your Ride" tab at least once.
  /// While false the map area renders a tinted placeholder, so the
  /// expensive [GoogleMap] platform view is not created on the same
  /// frame that the bottom navbar mounts (which would crash on Android
  /// without a Google Maps API key configured in AndroidManifest.xml).
  bool _mapMounted = false;

  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _passengers = List.of(kSamplePassengers);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  // ─── Phase machine ───────────────────────────────────────

  Passenger get _focus => _passengers[_currentIndex];

  int get _pickedCount =>
      _passengers.where((p) => p.status != PickupStatus.upcoming).length;

  /// Re-derive the right phase based on current passenger statuses.
  /// Called after every advance so the UI is always self-consistent.
  void _recomputePhase() {
    final allPicked =
        _passengers.every((p) => p.status != PickupStatus.upcoming);
    if (!allPicked) {
      final next =
          _passengers.indexWhere((p) => p.status == PickupStatus.upcoming);
      _currentIndex = next == -1 ? 0 : next;
      // First pickup reads as "Heading to pickup"; later ones as
      // "Heading to next pickup" so the copy matches naturally.
      _phase = _pickedCount == 0
          ? _RidePhase.headingToPickup
          : _RidePhase.inTransitNextPickup;
      return;
    }
    // All picked up — switch into drop-off cycle.
    final remainingDrops =
        _passengers.where((p) => p.status == PickupStatus.picked).toList();
    final nextDropIdx =
        _passengers.indexWhere((p) => p.status == PickupStatus.picked);
    if (nextDropIdx == -1) return;
    _currentIndex = nextDropIdx;
    _phase = remainingDrops.length == 1
        ? _RidePhase.lastDropoff
        : _RidePhase.inTransitDropoff;
  }

  void _advance() {
    setState(() {
      switch (_phase) {
        case _RidePhase.headingToPickup:
          _phase = _RidePhase.arrivedAtPickup;
          break;
        case _RidePhase.arrivedAtPickup:
        case _RidePhase.inTransitNextPickup:
          _passengers[_currentIndex] =
              _focus.copyWith(status: PickupStatus.picked);
          _recomputePhase();
          break;
        case _RidePhase.inTransitDropoff:
        case _RidePhase.lastDropoff:
          _passengers[_currentIndex] =
              _focus.copyWith(status: PickupStatus.dropped);
          if (_passengers
              .every((p) => p.status == PickupStatus.dropped)) {
            _completeTrip();
            return;
          }
          _recomputePhase();
          break;
      }
    });
  }

  void _completeTrip() {
    setState(() {
      _demoActive = false;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        CustomWidgets.customSuccessSnackBar("Trip completed"),
      );
  }

  void _restartDemo() {
    setState(() {
      _passengers = List.of(kSamplePassengers);
      _currentIndex = 0;
      _phase = _RidePhase.headingToPickup;
      _demoActive = true;
    });
  }

  // ─── Phase-driven copy ──────────────────────────────────

  String get _statusLine {
    switch (_phase) {
      case _RidePhase.headingToPickup:
        return "Heading to pickup · ETA ${_focus.etaToPickup}";
      case _RidePhase.arrivedAtPickup:
        return "Waiting for ${_focus.name}";
      case _RidePhase.inTransitNextPickup:
        return "Heading to next pickup · ${_focus.name}";
      case _RidePhase.inTransitDropoff:
        return "Heading to ${_focus.name}'s drop-off";
      case _RidePhase.lastDropoff:
        return "Final drop-off";
    }
  }

  String get _ctaLabel {
    switch (_phase) {
      case _RidePhase.headingToPickup:
        return "Arrived at Pickup";
      case _RidePhase.arrivedAtPickup:
      case _RidePhase.inTransitNextPickup:
        return "Picked up ${_focus.name.split(' ').first}";
      case _RidePhase.inTransitDropoff:
        return "Dropped off ${_focus.name.split(' ').first}";
      case _RidePhase.lastDropoff:
        return "Complete Trip";
    }
  }

  bool get _isPickupPhase =>
      _phase == _RidePhase.headingToPickup ||
      _phase == _RidePhase.arrivedAtPickup ||
      _phase == _RidePhase.inTransitNextPickup;

  String get _focusAddress => _isPickupPhase ? _focus.pickup : _focus.drop;

  // ─── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      body: Consumer(
        builder: (context, ref, _) {
          // Flip _mapMounted on the first frame after the tab becomes
          // selected. This keeps the GoogleMap out of the widget tree
          // until the user actually views this tab — avoids initializing
          // the platform view inside the IndexedStack on app launch
          // (which crashes natively on Android without a Maps API key).
          final selectedTab = ref.watch(bottomNavIndexProvider);
          if (!_mapMounted && selectedTab == _kYourRideTabIndex) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_mapMounted) {
                setState(() => _mapMounted = true);
              }
            });
          }

          if (!_demoActive) return _emptyState(ref);
          return _activeRide();
        },
      ),
    );
  }

  // ─── Active ride layout ─────────────────────────────────

  Widget _activeRide() {
    final media = MediaQuery.of(context);
    final mediaH = media.size.height;
    // Clamp the map portion so it stays usable on both very small phones
    // and tall foldables / tablets where a raw percentage would either
    // starve the bottom panel or shrink the map below readable height.
    final mapHeight = (mediaH * 0.40).clamp(240.0, 360.0);
    final bottomInset = media.padding.bottom;

    final remaining = <_RemainingItem>[];
    for (int i = 0; i < _passengers.length; i++) {
      if (i == _currentIndex) continue;
      final p = _passengers[i];
      if (p.status == PickupStatus.dropped) continue;
      remaining.add(
        _RemainingItem(
          passenger: p,
          asPickup: p.status == PickupStatus.upcoming,
        ),
      );
    }

    return Stack(
      // Without expand, the Stack would size itself to the map SizedBox
      // and the bottom panel would only get 28.h to render in — causing
      // the "BOTTOM OVERFLOWED" warning between drag handle and CTA.
      fit: StackFit.expand,
      children: [
        // ── Map (top portion) ──
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: mapHeight,
          child: _mapMounted
              ? const _RouteMap(
                  pickup: _pickup,
                  drop: _drop,
                  driver: _driver,
                  via1: _via1,
                  via2: _via2,
                )
              : _mapLoadingPlaceholder(),
        ),

        // ── Bottom panel (white sheet over the rest of the screen) ──
        Positioned(
          left: 0,
          right: 0,
          top: mapHeight - 28.h,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              color: Consonants.whiteColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28.r),
                topRight: Radius.circular(28.r),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              children: [
                SizedBox(height: 8.h),
                Container(
                  width: 44.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Consonants.lightGreyColor,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 8.h),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    children: [
                      _statusBand(),
                      SizedBox(height: 12.h),
                      _focusCard(),
                      SizedBox(height: 12.h),
                      _tripStrip(),
                      if (remaining.isNotEmpty) ...[
                        SizedBox(height: 18.h),
                        _remainingHeader(remaining.length),
                        SizedBox(height: 8.h),
                        for (final item in remaining) ...[
                          _remainingTile(item),
                          SizedBox(height: 8.h),
                        ],
                      ],
                      SizedBox(height: 16.h),
                    ],
                  ),
                ),
                _stickyCta(bottomInset),
              ],
            ),
          ),
        ),

        // ── Floating top bar (over map) ──
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 0),
              child: Row(
                children: [
                  _circleIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          CustomWidgets.customErrorSnackBar(
                            "Trip in progress — finish before leaving",
                          ),
                        );
                    },
                  ),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: Consonants.whiteColor,
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.directions_car_rounded,
                            size: 14.sp,
                            color: Consonants.primaryColor),
                        SizedBox(width: 5.w),
                        CustomWidgets.customText(
                          "Active Ride",
                          11.sp,
                          Consonants.boldTextColor,
                          FontWeight.w800,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _circleIconButton(
                    icon: Icons.shield_rounded,
                    iconColor: const Color(0xffEF4444),
                    onTap: () {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          CustomWidgets.customErrorSnackBar(
                            "Emergency support coming soon",
                          ),
                        );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Sub-widgets ────────────────────────────────────────

  Widget _circleIconButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40.w,
        height: 40.w,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Consonants.whiteColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon,
            size: 18.sp, color: iconColor ?? Consonants.boldTextColor),
      ),
    );
  }

  Widget _statusBand() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Consonants.lightBlueColor,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) {
              return Container(
                width: 10.w,
                height: 10.w,
                decoration: BoxDecoration(
                  color: Consonants.primaryColor.withValues(
                    alpha: 0.50 + 0.50 * _pulse.value,
                  ),
                  shape: BoxShape.circle,
                ),
              );
            },
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: CustomWidgets.customText(
              _statusLine,
              12.sp,
              Consonants.boldTextColor,
              FontWeight.w700,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _focusCard() {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: Consonants.lightGreyColor),
        boxShadow: [
          BoxShadow(
            color: Consonants.primaryColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52.w,
                height: 52.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _focus.avatarColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Consonants.whiteColor,
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _focus.avatarColor.withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  _focus.initial,
                  style: TextStyle(
                    color: Consonants.whiteColor,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
                    fontFamily: Consonants.fontFamily,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: CustomWidgets.customText(
                            _focus.name,
                            14.sp,
                            Consonants.boldTextColor,
                            FontWeight.w800,
                            maxLines: 1,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Icon(Icons.verified_rounded,
                            size: 14.sp, color: Consonants.primaryColor),
                      ],
                    ),
                    SizedBox(height: 3.h),
                    Row(
                      children: [
                        Icon(Icons.star_rounded,
                            size: 12.sp, color: const Color(0xffF5B800)),
                        SizedBox(width: 3.w),
                        Flexible(
                          child: CustomWidgets.customText(
                            _focus.rating,
                            11.sp,
                            Consonants.greyColor,
                            FontWeight.w700,
                            maxLines: 1,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          width: 3.w,
                          height: 3.w,
                          decoration: BoxDecoration(
                            color: Consonants.greyColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Flexible(
                          child: CustomWidgets.customText(
                            "${_focus.seats} ${_focus.seats == 1 ? 'seat' : 'seats'}",
                            11.sp,
                            Consonants.greyColor,
                            FontWeight.w600,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _phaseChip(),
            ],
          ),
          SizedBox(height: 14.h),
          Container(height: 1, color: Consonants.lightGreyColor),
          SizedBox(height: 12.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _isPickupPhase
                    ? Icons.my_location_rounded
                    : Icons.location_on_rounded,
                size: 16.sp,
                color: _isPickupPhase
                    ? Consonants.primaryColor
                    : const Color(0xffEF4444),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomWidgets.customText(
                      _isPickupPhase ? "PICKUP" : "DROP-OFF",
                      9.sp,
                      Consonants.greyColor,
                      FontWeight.w800,
                    ),
                    SizedBox(height: 2.h),
                    CustomWidgets.customText(
                      _focusAddress,
                      12.sp,
                      Consonants.boldTextColor,
                      FontWeight.w700,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: _quickAction(
                  icon: Icons.phone_rounded,
                  label: "Call",
                  onTap: () => _quickActionSnack("Calling ${_focus.name}…"),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _quickAction(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: "Message",
                  onTap: () => _quickActionSnack("Messages coming soon"),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _quickAction(
                  icon: Icons.navigation_rounded,
                  label: "Navigate",
                  onTap: () => _quickActionSnack("Opening directions…"),
                  primary: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _phaseChip() {
    final (label, fg, bg) = switch (_phase) {
      _RidePhase.headingToPickup => (
          "On the way",
          Consonants.primaryColor,
          Consonants.lightBlueColor,
        ),
      _RidePhase.arrivedAtPickup => (
          "Arrived",
          const Color(0xff15803D),
          Consonants.primaryGreenColor,
        ),
      _RidePhase.inTransitNextPickup => (
          "Next pickup",
          Consonants.primaryColor,
          Consonants.lightBlueColor,
        ),
      _RidePhase.inTransitDropoff => (
          "Dropping off",
          const Color(0xffEF4444),
          const Color(0xffFEE2E2),
        ),
      _RidePhase.lastDropoff => (
          "Final stop",
          const Color(0xffEF4444),
          const Color(0xffFEE2E2),
        ),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: CustomWidgets.customText(
        label,
        9.sp,
        fg,
        FontWeight.w800,
      ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          gradient: primary
              ? const LinearGradient(
                  colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
                )
              : null,
          color: primary ? null : Consonants.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: primary
              ? [
                  BoxShadow(
                    color: Consonants.primaryColor.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 18.sp,
              color:
                  primary ? Consonants.whiteColor : Consonants.boldTextColor,
            ),
            SizedBox(height: 4.h),
            CustomWidgets.customText(
              label,
              10.sp,
              primary ? Consonants.whiteColor : Consonants.boldTextColor,
              FontWeight.w700,
            ),
          ],
        ),
      ),
    );
  }

  void _quickActionSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(CustomWidgets.customSuccessSnackBar(message));
  }

  Widget _tripStrip() {
    final totalFare = _passengers.fold<int>(0, (sum, p) {
      final digits = p.fare.replaceAll(RegExp(r'[^0-9]'), '');
      return sum + (int.tryParse(digits) ?? 0);
    });
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Consonants.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: _stripItem(
              icon: Icons.straighten_rounded,
              value: "12.4 km",
              label: "Total",
            ),
          ),
          Container(
            width: 1,
            height: 26.h,
            color: Consonants.lightGreyColor,
          ),
          Expanded(
            child: _stripItem(
              icon: Icons.access_time_rounded,
              value: "32 min",
              label: "Duration",
            ),
          ),
          Container(
            width: 1,
            height: 26.h,
            color: Consonants.lightGreyColor,
          ),
          Expanded(
            child: _stripItem(
              icon: Icons.payments_rounded,
              value: "Rs $totalFare",
              label: "Total fare",
              accent: Consonants.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stripItem({
    required IconData icon,
    required String value,
    required String label,
    Color? accent,
  }) {
    return Column(
      children: [
        Icon(icon,
            size: 14.sp, color: accent ?? Consonants.boldTextColor),
        SizedBox(height: 4.h),
        CustomWidgets.customText(
          value,
          12.sp,
          accent ?? Consonants.boldTextColor,
          FontWeight.w800,
          maxLines: 1,
        ),
        SizedBox(height: 1.h),
        CustomWidgets.customText(
          label,
          9.sp,
          Consonants.greyColor,
          FontWeight.w500,
        ),
      ],
    );
  }

  Widget _remainingHeader(int count) {
    final allPicked =
        _passengers.every((p) => p.status != PickupStatus.upcoming);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Row(
        children: [
          CustomWidgets.customText(
            allPicked ? "REMAINING DROPS" : "NEXT PICKUPS",
            10.sp,
            Consonants.greyColor,
            FontWeight.w800,
          ),
          SizedBox(width: 6.w),
          CustomWidgets.customText(
            "($count)",
            10.sp,
            Consonants.greyColor,
            FontWeight.w600,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Container(height: 1, color: Consonants.lightGreyColor),
          ),
        ],
      ),
    );
  }

  Widget _remainingTile(_RemainingItem item) {
    return GestureDetector(
      onTap: () => _quickActionSnack("Passenger details coming soon"),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Consonants.whiteColor,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: Consonants.lightGreyColor),
        ),
        child: Row(
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: item.passenger.avatarColor,
                shape: BoxShape.circle,
              ),
              child: Text(
                item.passenger.initial,
                style: TextStyle(
                  color: Consonants.whiteColor,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  fontFamily: Consonants.fontFamily,
                ),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomWidgets.customText(
                    item.passenger.name,
                    12.sp,
                    Consonants.boldTextColor,
                    FontWeight.w700,
                    maxLines: 1,
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    children: [
                      Icon(
                        item.asPickup
                            ? Icons.my_location_rounded
                            : Icons.location_on_rounded,
                        size: 11.sp,
                        color: item.asPickup
                            ? Consonants.primaryColor
                            : const Color(0xffEF4444),
                      ),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: CustomWidgets.customText(
                          item.asPickup
                              ? item.passenger.pickup
                              : item.passenger.drop,
                          10.sp,
                          Consonants.greyColor,
                          FontWeight.w500,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Icon(Icons.chevron_right_rounded,
                size: 18.sp, color: Consonants.greyColor),
          ],
        ),
      ),
    );
  }

  Widget _stickyCta(double bottomInset) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h + bottomInset),
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: _advance,
        child: Container(
          height: 54.h,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
            ),
            borderRadius: BorderRadius.circular(40.r),
            boxShadow: [
              BoxShadow(
                color: Consonants.primaryColor.withValues(alpha: 0.30),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: CustomWidgets.customText(
                    _ctaLabel,
                    14.sp,
                    Consonants.whiteColor,
                    FontWeight.w800,
                    maxLines: 1,
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(
                  _phase == _RidePhase.lastDropoff
                      ? Icons.check_circle_rounded
                      : Icons.arrow_forward_rounded,
                  size: 18.sp,
                  color: Consonants.whiteColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Map ────────────────────────────────────────────────
  // The actual GoogleMap is rendered by [_RouteMap] (a ConsumerWidget
  // defined below) so it can watch [directionsProvider] for the real
  // road polyline + ETA.

  /// Tinted placeholder shown while the map hasn't been requested yet.
  /// Same height as [_mapView] so the bottom panel doesn't jump on swap.
  Widget _mapLoadingPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Consonants.lightBlueColor,
            Consonants.scaffoldBackgroundColor,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_rounded,
              size: 36.sp, color: Consonants.primaryColor),
          SizedBox(height: 8.h),
          CustomWidgets.customText(
            "Loading map…",
            11.sp,
            Consonants.greyColor,
            FontWeight.w600,
          ),
        ],
      ),
    );
  }

  // ─── Empty state ────────────────────────────────────────

  Widget _emptyState(WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96.w,
              height: 96.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Consonants.primaryColor.withValues(alpha: 0.15),
                    const Color(0xff5AC8FA).withValues(alpha: 0.15),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.route_rounded,
                size: 42.sp,
                color: Consonants.primaryColor,
              ),
            ),
            SizedBox(height: 18.h),
            CustomWidgets.customText(
              "No active ride right now",
              16.sp,
              Consonants.boldTextColor,
              FontWeight.w800,
            ),
            SizedBox(height: 6.h),
            CustomWidgets.customText(
              "Accepted rides from the Rides tab will appear here",
              11.sp,
              Consonants.greyColor,
              FontWeight.w500,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 22.h),
            GestureDetector(
              onTap: () =>
                  ref.read(bottomNavIndexProvider.notifier).select(1),
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 22.w, vertical: 12.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
                  ),
                  borderRadius: BorderRadius.circular(40.r),
                  boxShadow: [
                    BoxShadow(
                      color: Consonants.primaryColor.withValues(alpha: 0.30),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.directions_car_rounded,
                        size: 16.sp, color: Consonants.whiteColor),
                    SizedBox(width: 6.w),
                    CustomWidgets.customText(
                      "Go to Rides",
                      13.sp,
                      Consonants.whiteColor,
                      FontWeight.w800,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 14.h),
            GestureDetector(
              onTap: _restartDemo,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 6.h),
                child: CustomWidgets.customText(
                  "Start demo ride",
                  11.sp,
                  Consonants.greyColor,
                  FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RemainingItem {
  final Passenger passenger;
  final bool asPickup;
  const _RemainingItem({required this.passenger, required this.asPickup});
}

// ─────────────────────────────────────────────────────────────────────────────
// Live route map
//
// Renders the active-ride map. The polyline points come from the Directions
// API via [directionsProvider] when it resolves; until then (and on any
// failure / missing key) we fall back to the hand-picked `_pickup → _via1
// → _driver → _via2 → _drop` waypoints so the screen still renders a route.
// ─────────────────────────────────────────────────────────────────────────────

class _RouteMap extends ConsumerWidget {
  final LatLng pickup;
  final LatLng drop;
  final LatLng driver;
  final LatLng via1;
  final LatLng via2;

  const _RouteMap({
    required this.pickup,
    required this.drop,
    required this.driver,
    required this.via1,
    required this.via2,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(directionsProvider(
      DirectionsRequest(origin: pickup, destination: drop),
    ));
    final routePoints = async.maybeWhen(
      data: (r) => r.points,
      orElse: () => <LatLng>[pickup, via1, driver, via2, drop],
    );

    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(31.5210, 74.3565),
        zoom: 13.5,
      ),
      style: kMinimalMapStyle,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      markers: {
        Marker(
          markerId: const MarkerId("pickup"),
          position: pickup,
          infoWindow: const InfoWindow(title: "Pickup"),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure),
        ),
        Marker(
          markerId: const MarkerId("drop"),
          position: drop,
          infoWindow: const InfoWindow(title: "Drop-off"),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed),
        ),
        Marker(
          markerId: const MarkerId("driver"),
          position: driver,
          infoWindow: const InfoWindow(title: "You"),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen),
        ),
      },
      polylines: {
        Polyline(
          polylineId: const PolylineId("route"),
          color: Consonants.primaryColor,
          width: 4,
          points: routePoints,
        ),
      },
    );
  }
}
