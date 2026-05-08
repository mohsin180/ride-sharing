import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ride_sharing/provider/directionsProvider.dart';
import 'package:ride_sharing/provider/mapProvider.dart' show kMinimalMapStyle;
import 'package:ride_sharing/view/bottomNavbar.dart' show bottomNavIndexProvider;
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

/// Index of the "Your Ride" tab inside [bottomNavIndexProvider]. Used to
/// lazily mount the [GoogleMap] only after the user has visited this tab
/// at least once (mirrors the same pattern in `driverYourRide.dart`).
const int _kPassengerRideTabIndex = 2;

/// Index of the "Ride" tab — used by the empty state to deep-link the
/// passenger back into the booking flow when no trip is active.
const int _kRideTabIndex = 1;

/// Passenger "Your Ride" tab — the active-trip cockpit from the rider's
/// perspective.
///
/// Shown while a passenger has an accepted ride: live route map up top,
/// a status banner that flips through phases, a driver/vehicle focus
/// card with quick actions, a trip strip and a sticky CTA that mirrors
/// the user's natural next action ("Driver arrived" → "I'm in the car"
/// → "I've reached"). When there's no active ride the tab falls back
/// to a clean empty state with a shortcut into the Ride tab.
///
/// State is local for now (`_demoActive`, `_phase`) — same approach as
/// the driver counterpart. Lift into a provider once the rides API
/// lands so other tabs can react to the in-progress trip.
class Passengeryourride extends StatefulWidget {
  const Passengeryourride({super.key});

  @override
  State<Passengeryourride> createState() => _PassengeryourrideState();
}

enum _RidePhase {
  driverEnRoute,
  driverArrived,
  inTransit,
  arrived,
}

class _PassengeryourrideState extends State<Passengeryourride>
    with TickerProviderStateMixin {
  // Hardcoded route in the Lahore area — same coords as the driver view
  // so both perspectives feel like the same trip during demos.
  static const _pickup = LatLng(31.5142, 74.3625);
  static const _drop = LatLng(31.5290, 74.3500);
  static const _driverLoc = LatLng(31.5180, 74.3590);
  static const _via1 = LatLng(31.5210, 74.3585);
  static const _via2 = LatLng(31.5260, 74.3540);

  static const _pickupAddr = "Liberty Market, Gulberg III, Lahore";
  static const _dropAddr = "DHA Phase 5, Sector A, Lahore";

  _RidePhase _phase = _RidePhase.driverEnRoute;
  bool _demoActive = true;

  /// True once the user has selected the "Your Ride" tab at least once.
  /// Same lazy-mount trick as the driver screen — keeps the GoogleMap
  /// platform view out of the IndexedStack until visited.
  bool _mapMounted = false;

  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
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

  void _advance() {
    switch (_phase) {
      case _RidePhase.driverEnRoute:
        setState(() => _phase = _RidePhase.driverArrived);
        break;
      case _RidePhase.driverArrived:
        setState(() => _phase = _RidePhase.inTransit);
        break;
      case _RidePhase.inTransit:
        setState(() => _phase = _RidePhase.arrived);
        _completeTrip();
        break;
      case _RidePhase.arrived:
        break;
    }
  }

  void _completeTrip() {
    setState(() => _demoActive = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        CustomWidgets.customSuccessSnackBar(
          "Trip completed — thanks for riding!",
        ),
      );
  }

  void _restartDemo() {
    setState(() {
      _phase = _RidePhase.driverEnRoute;
      _demoActive = true;
    });
  }

  void _confirmCancel() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Consonants.whiteColor,
          insetPadding: EdgeInsets.symmetric(horizontal: 32.w),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56.w,
                  height: 56.w,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xffFEE2E2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.cancel_outlined,
                      size: 26.sp, color: const Color(0xffEF4444)),
                ),
                SizedBox(height: 14.h),
                CustomWidgets.customText(
                  "Cancel ride?",
                  16.sp,
                  Consonants.boldTextColor,
                  FontWeight.w800,
                ),
                SizedBox(height: 6.h),
                CustomWidgets.customText(
                  "Frequent cancellations may affect your account.",
                  11.sp,
                  Consonants.greyColor,
                  FontWeight.w500,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
                SizedBox(height: 20.h),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.of(dialogCtx).pop(),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Consonants.scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: CustomWidgets.customText(
                            "Keep ride",
                            13.sp,
                            Consonants.boldTextColor,
                            FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(dialogCtx).pop();
                          _completeTripCancelled();
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xffEF4444), Color(0xffF87171)],
                            ),
                            borderRadius: BorderRadius.circular(12.r),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xffEF4444)
                                    .withValues(alpha: 0.30),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CustomWidgets.customText(
                            "Cancel ride",
                            13.sp,
                            Consonants.whiteColor,
                            FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _completeTripCancelled() {
    setState(() => _demoActive = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        CustomWidgets.customErrorSnackBar("Ride cancelled"),
      );
  }

  // ─── Phase-driven copy ──────────────────────────────────

  String get _statusLine {
    switch (_phase) {
      case _RidePhase.driverEnRoute:
        return "Driver on the way · ETA ${_kSampleDriver.etaToPickup}";
      case _RidePhase.driverArrived:
        return "Your driver has arrived";
      case _RidePhase.inTransit:
        return "Heading to your drop-off · 12 min";
      case _RidePhase.arrived:
        return "You've arrived at your destination";
    }
  }

  String get _ctaLabel {
    switch (_phase) {
      case _RidePhase.driverEnRoute:
        return "Driver Arrived";
      case _RidePhase.driverArrived:
        return "I'm in the car";
      case _RidePhase.inTransit:
        return "I've Reached";
      case _RidePhase.arrived:
        return "Done";
    }
  }

  /// True while the relevant focus location is the pickup. Switches to
  /// the drop-off once the rider boards.
  bool get _isPickupPhase =>
      _phase == _RidePhase.driverEnRoute ||
      _phase == _RidePhase.driverArrived;

  // ─── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      body: Consumer(
        builder: (context, ref, _) {
          // Same lazy-mount trick used in driverYourRide — only build the
          // GoogleMap platform view once the user has visited this tab.
          final selectedTab = ref.watch(bottomNavIndexProvider);
          if (!_mapMounted && selectedTab == _kPassengerRideTabIndex) {
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
    // Same clamp the driver view uses — keeps the map readable on tiny
    // phones and stops it eating the panel on tall foldables/tablets.
    final mapHeight = (mediaH * 0.40).clamp(240.0, 360.0);
    final bottomInset = media.padding.bottom;

    return Stack(
      // Without expand, the Stack would size itself to the map and the
      // bottom panel would only get 28.h to render in.
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
                  driver: _driverLoc,
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
                      _driverCard(),
                      SizedBox(height: 12.h),
                      _tripStrip(),
                      SizedBox(height: 14.h),
                      _routeCard(),
                      SizedBox(height: 14.h),
                      _safetyTile(),
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
                            "Trip in progress — cancel before leaving",
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
                          "Live Trip",
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
    final isArrivedBanner = _phase == _RidePhase.driverArrived;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: isArrivedBanner
            ? Consonants.primaryGreenColor
            : Consonants.lightBlueColor,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) {
              final color = isArrivedBanner
                  ? const Color(0xff15803D)
                  : Consonants.primaryColor;
              return Container(
                width: 10.w,
                height: 10.w,
                decoration: BoxDecoration(
                  color: color.withValues(
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
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _driverCard() {
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
                  color: _kSampleDriver.avatarColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Consonants.whiteColor,
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _kSampleDriver.avatarColor
                          .withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  _kSampleDriver.initial,
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
                            _kSampleDriver.name,
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
                            size: 12.sp,
                            color: const Color(0xffF5B800)),
                        SizedBox(width: 3.w),
                        Flexible(
                          child: CustomWidgets.customText(
                            _kSampleDriver.rating,
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
                            _kSampleDriver.vehicleColor,
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
            children: [
              Container(
                width: 38.w,
                height: 38.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Consonants.lightBlueColor,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(Icons.directions_car_rounded,
                    size: 18.sp, color: Consonants.primaryColor),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomWidgets.customText(
                      _kSampleDriver.vehicleModel,
                      12.sp,
                      Consonants.boldTextColor,
                      FontWeight.w800,
                      maxLines: 1,
                    ),
                    SizedBox(height: 2.h),
                    CustomWidgets.customText(
                      _kSampleDriver.vehicleColor,
                      10.sp,
                      Consonants.greyColor,
                      FontWeight.w500,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Consonants.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(8.r),
                  border:
                      Border.all(color: Consonants.lightGreyColor),
                ),
                child: CustomWidgets.customText(
                  _kSampleDriver.vehiclePlate,
                  12.sp,
                  Consonants.boldTextColor,
                  FontWeight.w800,
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
                  onTap: () => _quickActionSnack(
                      "Calling ${_kSampleDriver.name}…"),
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
                  icon: Icons.share_location_rounded,
                  label: "Share",
                  onTap: () =>
                      _quickActionSnack("Sharing live trip status…"),
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
      _RidePhase.driverEnRoute => (
          "On the way",
          Consonants.primaryColor,
          Consonants.lightBlueColor,
        ),
      _RidePhase.driverArrived => (
          "Arrived",
          const Color(0xff15803D),
          Consonants.primaryGreenColor,
        ),
      _RidePhase.inTransit => (
          "In transit",
          Consonants.primaryColor,
          Consonants.lightBlueColor,
        ),
      _RidePhase.arrived => (
          "Reached",
          const Color(0xff15803D),
          Consonants.primaryGreenColor,
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
              label: "Distance",
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
              value: "Rs 480",
              label: "Fare",
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

  Widget _routeCard() {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Consonants.lightGreyColor),
      ),
      child: Column(
        children: [
          _routePoint(
            icon: Icons.my_location_rounded,
            iconColor: Consonants.primaryColor,
            label: "PICKUP",
            address: _pickupAddr,
            highlight: _isPickupPhase,
          ),
          Padding(
            padding: EdgeInsets.only(left: 11.w, top: 4.h, bottom: 4.h),
            child: Column(
              children: List.generate(
                4,
                (i) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 1.h),
                  child: Container(
                    width: 2.w,
                    height: 3.h,
                    color: Consonants.lightGreyColor,
                  ),
                ),
              ),
            ),
          ),
          _routePoint(
            icon: Icons.location_on_rounded,
            iconColor: const Color(0xffEF4444),
            label: "DROP-OFF",
            address: _dropAddr,
            highlight: !_isPickupPhase,
          ),
        ],
      ),
    );
  }

  Widget _routePoint({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String address,
    required bool highlight,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16.sp, color: iconColor),
        SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CustomWidgets.customText(
                    label,
                    9.sp,
                    Consonants.greyColor,
                    FontWeight.w800,
                  ),
                  if (highlight) ...[
                    SizedBox(width: 6.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: Consonants.lightBlueColor,
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: CustomWidgets.customText(
                        "NOW",
                        8.sp,
                        Consonants.primaryColor,
                        FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: 2.h),
              CustomWidgets.customText(
                address,
                12.sp,
                Consonants.boldTextColor,
                FontWeight.w700,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _safetyTile() {
    return GestureDetector(
      onTap: () =>
          _quickActionSnack("Live location shared with your contacts"),
      child: Container(
        padding:
            EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Consonants.lightBlueColor,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Row(
          children: [
            Icon(Icons.shield_rounded,
                size: 18.sp, color: Consonants.primaryColor),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomWidgets.customText(
                    "Ride safely",
                    12.sp,
                    Consonants.boldTextColor,
                    FontWeight.w800,
                  ),
                  SizedBox(height: 2.h),
                  CustomWidgets.customText(
                    "Verify the vehicle plate before boarding",
                    10.sp,
                    Consonants.greyColor,
                    FontWeight.w500,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18.sp, color: Consonants.greyColor),
          ],
        ),
      ),
    );
  }

  Widget _stickyCta(double bottomInset) {
    final canCancel = _phase == _RidePhase.driverEnRoute ||
        _phase == _RidePhase.driverArrived;
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
      child: Row(
        children: [
          if (canCancel) ...[
            GestureDetector(
              onTap: _confirmCancel,
              child: Container(
                height: 54.h,
                width: 54.h,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xffFEE2E2),
                  borderRadius: BorderRadius.circular(40.r),
                ),
                child: Icon(Icons.close_rounded,
                    size: 22.sp, color: const Color(0xffEF4444)),
              ),
            ),
            SizedBox(width: 10.w),
          ],
          Expanded(
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
                      color:
                          Consonants.primaryColor.withValues(alpha: 0.30),
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
                        _phase == _RidePhase.inTransit
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
          ),
        ],
      ),
    );
  }

  // ─── Map placeholder ───────────────────────────────────

  /// Tinted placeholder shown while the map hasn't been requested yet.
  /// Same height as the real map so the bottom panel doesn't jump on swap.
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
              "Your booked ride will appear here once a driver accepts.",
              11.sp,
              Consonants.greyColor,
              FontWeight.w500,
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
            SizedBox(height: 22.h),
            GestureDetector(
              onTap: () => ref
                  .read(bottomNavIndexProvider.notifier)
                  .select(_kRideTabIndex),
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
                      "Book a Ride",
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

// ─────────────────────────────────────────────────────────────────────────────
// Sample driver data
//
// Hardcoded for now while the demo runs entirely client-side. Lift into
// an `activeRideProvider` once the backend assigns a real driver to the
// passenger's request.
// ─────────────────────────────────────────────────────────────────────────────

class _Driver {
  final String name;
  final String initial;
  final String rating;
  final String vehicleModel;
  final String vehicleColor;
  final String vehiclePlate;
  final String etaToPickup;
  final Color avatarColor;

  const _Driver({
    required this.name,
    required this.initial,
    required this.rating,
    required this.vehicleModel,
    required this.vehicleColor,
    required this.vehiclePlate,
    required this.etaToPickup,
    required this.avatarColor,
  });
}

const _Driver _kSampleDriver = _Driver(
  name: "Ahmed Khan",
  initial: "A",
  rating: "4.92",
  vehicleModel: "Toyota Corolla",
  vehicleColor: "Silver",
  vehiclePlate: "LEA-2143",
  etaToPickup: "3 min",
  avatarColor: Color(0xff5AC8FA),
);

// ─────────────────────────────────────────────────────────────────────────────
// Live route map
//
// Mirrors the driver-side `_RouteMap` — fetches the real road polyline via
// [directionsProvider] and falls back to `pickup → via1 → driver → via2 →
// drop` waypoints until it resolves.
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
          infoWindow: const InfoWindow(title: "Your driver"),
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
