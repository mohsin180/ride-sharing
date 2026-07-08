import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/directionsProvider.dart';
import 'package:ride_sharing/provider/passengerActiveRideProvider.dart';
import 'package:ride_sharing/provider/providers.dart';
import 'package:ride_sharing/provider/rideTrackingProvider.dart';
import 'package:ride_sharing/view/bottomNavbar.dart' show bottomNavIndexProvider;
import 'package:ride_sharing/view/driverScreens/driverChatDetail.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
import 'package:ride_sharing/widgets/consonants/jwtUtils.dart';
import 'package:ride_sharing/widgets/consonants/tokenStorage.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';
import 'package:ride_sharing/widgets/custom/liveTrackingMap.dart';
import 'package:ride_sharing/widgets/custom/ratingSheet.dart';
import 'package:url_launcher/url_launcher.dart';

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
/// a status banner that reflects the trip phase, a driver/vehicle focus
/// card with quick actions, a trip strip and a sticky bar (cancel before
/// the trip moves, a passive status once it's underway). When there's no
/// active ride the tab falls back to a clean empty state with a shortcut
/// into the Ride tab.
///
/// The phase is DERIVED from the ride's real backend status
/// (`_phaseFor(ride.status)`): ACCEPTED → driver en route, ARRIVED →
/// driver arrived, STARTED → in transit. The driver drives the real
/// state machine; this screen only mirrors it (updated on the active-trip
/// provider's poll).
class Passengeryourride extends ConsumerStatefulWidget {
  const Passengeryourride({super.key});

  @override
  ConsumerState<Passengeryourride> createState() => _PassengeryourrideState();
}

enum _RidePhase {
  driverEnRoute,
  driverArrived,
  inTransit,
  arrived,
}

class _PassengeryourrideState extends ConsumerState<Passengeryourride>
    with TickerProviderStateMixin {
  // Lahore-area fallback used only when a ride is missing usable lat/lng.
  static const _pickup = LatLng(31.5142, 74.3625);
  static const _drop = LatLng(31.5290, 74.3500);

  /// The trip phase shown to the passenger. This is a DERIVED cache of the
  /// ride's real backend status (set at the top of [_activeRide] each build),
  /// not something the passenger drives. The driver advances the real state
  /// machine; the passenger's screen only reflects it.
  _RidePhase _phase = _RidePhase.driverEnRoute;

  /// Map the authoritative backend ride status to the passenger-facing phase.
  _RidePhase _phaseFor(RideStatus status) {
    switch (status) {
      case RideStatus.arrived:
        return _RidePhase.driverArrived;
      case RideStatus.started:
        return _RidePhase.inTransit;
      case RideStatus.accepted:
      default:
        return _RidePhase.driverEnRoute;
    }
  }

  /// True once the user has selected the "Your Ride" tab at least once.
  /// Same lazy-mount trick as the driver screen — keeps the GoogleMap
  /// platform view out of the IndexedStack until visited.
  bool _mapMounted = false;

  /// The authenticated user's id, read from the JWT once on init. Used to
  /// decide host-vs-co-passenger when cancelling a ride.
  String? _myUserId;

  /// Guards the cancel call so a double-tap can't fire two requests.
  bool _cancelling = false;

  /// Last active trip we saw, so when it leaves the active list (completed)
  /// we can prompt this passenger to rate the driver + co-passengers.
  RideDetails? _lastActiveRide;

  /// Ride ids we've already shown the rating prompt for — never twice.
  final Set<String> _ratedRides = {};

  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _loadMyUserId();
  }

  Future<void> _loadMyUserId() async {
    final token = await Tokenstorage.getToken();
    if (!mounted || token == null) return;
    setState(() => _myUserId = JwtUtils.extractUserId(token));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  // ─── Cancellation ────────────────────────────────────────

  void _confirmCancel(RideDetails ride) {
    // A fee applies only when the host cancels after the driver has already
    // reached the pickup (ride ARRIVED). Everyone else / earlier is free.
    final isHost = _myUserId != null && ride.host.id == _myUserId;
    final feeApplies = isHost && ride.status == RideStatus.arrived;
    final subtitle = feeApplies
        ? "Your driver has already arrived, so a cancellation fee applies."
        : "Frequent cancellations may affect your account.";
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
                  subtitle,
                  11.sp,
                  feeApplies ? const Color(0xffEF4444) : Consonants.greyColor,
                  feeApplies ? FontWeight.w700 : FontWeight.w500,
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
                          _cancelRide(ride);
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

  /// Cancels (host) or leaves (co-passenger) the active ride on the backend.
  /// Host-vs-co-passenger is decided by comparing the ride's host id to the
  /// authenticated user id from the JWT. On success we invalidate the
  /// active-ride provider and pop back; backend rejections (e.g. cancelling
  /// a STARTED ride) surface via [ErrorHandler] rather than crashing.
  Future<void> _cancelRide(RideDetails ride) async {
    if (_cancelling) return;
    setState(() => _cancelling = true);

    final isHost = _myUserId != null && ride.host.id == _myUserId;
    try {
      final service = ref.read(rideServiceProvider);
      CancellationResult? result;
      if (isHost) {
        result = await service.cancelRide(ride.id);
      } else {
        await service.leaveRide(ride.id);
      }
      if (!mounted) return;
      ref.invalidate(passengerActiveRideProvider);
      // If a fee was recorded (cancelled after the driver arrived), say so.
      final message = result != null && result.hasFee
          ? "Ride cancelled · ${result.feeLabel} fee applied"
          : isHost
              ? "Ride cancelled"
              : "You left the ride";
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(CustomWidgets.customSuccessSnackBar(message));
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  // ─── Action launches ────────────────────────────────────

  /// Emergency hotline (Pakistan Rescue 1122).
  Future<void> _emergencyCall() async {
    await _launch(Uri(scheme: 'tel', path: '1122'),
        fallback: "Couldn't reach emergency services");
  }

  /// Opens the ride's group chat — same `DriverChatDetail` screen the
  /// Messages tab pushes, keyed by the ride id.
  void _openChat(RideDetails ride) {
    final driver = ride.driver;
    final title = driver != null && driver.displayName.trim().isNotEmpty
        ? driver.displayName
        : "Ride chat";
    final members = driver != null
        ? [ChatMember(initial: driver.initial, color: Consonants.primaryColor)]
        : const <ChatMember>[];
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DriverChatDetail(
          rideId: ride.id,
          title: title,
          members: members,
          isActive: true,
        ),
      ),
    );
  }

  /// Guarded `launchUrl` with a SnackBar fallback when the platform can't
  /// handle the URI (no dialer, no maps app, etc.).
  Future<void> _launch(
    Uri uri, {
    LaunchMode mode = LaunchMode.platformDefault,
    required String fallback,
  }) async {
    try {
      if (await canLaunchUrl(uri) && await launchUrl(uri, mode: mode)) {
        return;
      }
    } catch (_) {
      // fall through to the snackbar below
    }
    if (mounted) _quickActionSnack(fallback);
  }

  // ─── Phase-driven copy ──────────────────────────────────

  String get _statusLine {
    switch (_phase) {
      case _RidePhase.driverEnRoute:
        return "Driver on the way to pick you up";
      case _RidePhase.driverArrived:
        return "Your driver has arrived";
      case _RidePhase.inTransit:
        return "Heading to your drop-off";
      case _RidePhase.arrived:
        return "You've arrived at your destination";
    }
  }

  // ─── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Lazy-mount the map only once the user has visited this tab.
    final selectedTab = ref.watch(bottomNavIndexProvider);
    if (!_mapMounted && selectedTab == _kPassengerRideTabIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_mapMounted) {
          setState(() => _mapMounted = true);
        }
      });
    }

    // Real in-progress trip (ACCEPTED/STARTED) the passenger is on. Use
    // `.value` (not maybeWhen-data) so the screen keeps showing the trip
    // during the 8s background refetch instead of flashing the empty state.
    final activeRides =
        ref.watch(passengerActiveRideProvider).value ?? const <RideDetails>[];
    final ride = activeRides.isNotEmpty ? activeRides.first : null;

    // When the active trip disappears after having STARTED, it just completed
    // — prompt this passenger to rate the driver + co-passengers (once).
    ref.listen<AsyncValue<List<RideDetails>>>(passengerActiveRideProvider,
        (prev, next) {
      final list = next.value;
      if (list == null) return; // first load still in flight
      final current = list.isNotEmpty ? list.first : null;
      if (current != null) {
        _lastActiveRide = current;
        return;
      }
      final finished = _lastActiveRide;
      _lastActiveRide = null;
      if (finished == null || _ratedRides.contains(finished.id)) return;
      // Only after a trip that actually started (not a cancelled-before-start).
      if (finished.status != RideStatus.started) return;
      _ratedRides.add(finished.id);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _promptRideRatings(finished);
      });
    });

    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      body: ride == null ? _emptyState() : _activeRide(ride),
    );
  }

  /// After a completed trip: rate the driver, then each co-passenger. Each
  /// prompt is skippable; a failed submit is swallowed so one error doesn't
  /// block the rest.
  Future<void> _promptRideRatings(RideDetails ride) async {
    if (ride.driver != null) {
      final stars = await showRatingSheet(
        context: context,
        title: 'Rate your driver',
        subtitle: 'How was your trip?',
      );
      if (stars != null) {
        try {
          await ref.read(rideServiceProvider).rateDriver(ride.id, stars);
        } catch (_) {}
      }
    }
    if (!mounted) return;
    for (final c in ride.coPassengers) {
      if (!mounted || c.id.isEmpty) continue;
      final name = c.name.trim().isEmpty ? 'co-passenger' : c.name.trim();
      final stars = await showRatingSheet(
        context: context,
        title: 'Rate $name',
        subtitle: 'How was riding with them?',
        avatarInitial: name[0].toUpperCase(),
      );
      if (stars != null) {
        try {
          await ref.read(rideServiceProvider).rateCoPassenger(ride.id, c.id, stars);
        } catch (_) {}
      }
    }
  }

  // ─── Co-riders (matches the driver's remaining-passengers section) ──
  Widget _coRidersHeader(int count) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Row(
        children: [
          CustomWidgets.customText(
              "CO-RIDERS", 10.sp, Consonants.greyColor, FontWeight.w800),
          SizedBox(width: 6.w),
          CustomWidgets.customText(
              "($count)", 10.sp, Consonants.greyColor, FontWeight.w600),
          SizedBox(width: 10.w),
          Expanded(
              child: Container(height: 1, color: Consonants.lightGreyColor)),
        ],
      ),
    );
  }

  Widget _coRiderTile(RideCoPassenger c) {
    final name = c.name.trim().isEmpty ? "Passenger" : c.name.trim();
    final rating = (c.rating != null && c.rating! > 0)
        ? c.rating!.toStringAsFixed(1)
        : "New";
    return GestureDetector(
      onTap: () => _showCoRiderDetails(c),
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
              decoration: const BoxDecoration(
                color: Consonants.primaryColor,
                shape: BoxShape.circle,
              ),
              child: CustomWidgets.customText(name[0].toUpperCase(), 14.sp,
                  Consonants.whiteColor, FontWeight.w800),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomWidgets.customText(
                      name, 12.sp, Consonants.boldTextColor, FontWeight.w700,
                      maxLines: 1),
                  SizedBox(height: 2.h),
                  Row(
                    children: [
                      Icon(Icons.star_rounded,
                          size: 11.sp, color: const Color(0xffF5B800)),
                      SizedBox(width: 4.w),
                      CustomWidgets.customText(
                          rating, 10.sp, Consonants.greyColor, FontWeight.w500),
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

  void _showCoRiderDetails(RideCoPassenger c) {
    final name = c.name.trim().isEmpty ? "Passenger" : c.name.trim();
    final rating = (c.rating != null && c.rating! > 0)
        ? c.rating!.toStringAsFixed(1)
        : "New";
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Consonants.whiteColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                height: 5.h,
                width: 44.w,
                decoration: BoxDecoration(
                  color: Consonants.lightGreyColor,
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
            ),
            SizedBox(height: 18.h),
            Row(
              children: [
                Container(
                  width: 52.w,
                  height: 52.w,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Consonants.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: CustomWidgets.customText(name[0].toUpperCase(), 20.sp,
                      Consonants.whiteColor, FontWeight.w800),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomWidgets.customText(name, 16.sp,
                          Consonants.boldTextColor, FontWeight.w800,
                          maxLines: 1),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              size: 14.sp, color: const Color(0xffF5B800)),
                          SizedBox(width: 4.w),
                          CustomWidgets.customText(rating, 12.sp,
                              Consonants.greyColor, FontWeight.w600),
                          SizedBox(width: 8.w),
                          CustomWidgets.customText("Co-rider", 10.sp,
                              Consonants.primaryColor, FontWeight.w700),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Active ride layout ─────────────────────────────────

  Widget _activeRide(RideDetails ride) {
    // Derive the passenger-facing phase from the authoritative ride status,
    // so the banner/chip below track what the driver actually did.
    _phase = _phaseFor(ride.status);
    final hasCoords = ride.pickupLat != null &&
        ride.pickupLng != null &&
        ride.dropLat != null &&
        ride.dropLng != null;
    final pickupLL =
        hasCoords ? LatLng(ride.pickupLat!, ride.pickupLng!) : _pickup;
    final dropLL = hasCoords ? LatLng(ride.dropLat!, ride.dropLng!) : _drop;

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
              ? LiveTrackingMap(
                  rideId: ride.id,
                  pickup: pickupLL,
                  drop: dropLL,
                  myRole: 'PASSENGER',
                  // Show the full multi-stop route (all co-passengers) in
                  // shortest order, matching the driver's map.
                  stops: ride.stops,
                  hostId: ride.host.id,
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
                      // Below-map layout mirrors the driver's active-ride
                      // cockpit: status band → focus card → trip strip →
                      // co-riders list. (The full route is on the map now, so
                      // the old text route card is dropped — same as the driver.)
                      _statusBand(),
                      SizedBox(height: 12.h),
                      _driverCard(ride),
                      SizedBox(height: 12.h),
                      _tripStrip(ride, pickupLL, dropLL),
                      if (ride.fare != null) ...[
                        SizedBox(height: 12.h),
                        _cashPaymentHint(ride),
                      ],
                      if (ride.coPassengers.isNotEmpty) ...[
                        SizedBox(height: 18.h),
                        _coRidersHeader(ride.coPassengers.length),
                        SizedBox(height: 8.h),
                        for (final c in ride.coPassengers) ...[
                          _coRiderTile(c),
                          SizedBox(height: 8.h),
                        ],
                      ],
                      SizedBox(height: 14.h),
                      _safetyTile(),
                      SizedBox(height: 16.h),
                    ],
                  ),
                ),
                _stickyCta(ride, bottomInset),
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
                    onTap: _emergencyCall,
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

  Widget _driverCard(RideDetails ride) {
    final driver = ride.driver;

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
      child: driver == null
          ? _driverPending()
          : _driverDetails(ride, driver),
    );
  }

  /// Graceful placeholder shown when the backend hasn't attached a driver
  /// to the ride yet (e.g. the host cancelled / re-assigned).
  Widget _driverPending() {
    return Row(
      children: [
        Container(
          width: 52.w,
          height: 52.w,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Consonants.lightBlueColor,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.person_search_rounded,
              size: 24.sp, color: Consonants.primaryColor),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomWidgets.customText(
                "Driver assigned soon",
                14.sp,
                Consonants.boldTextColor,
                FontWeight.w800,
                maxLines: 1,
              ),
              SizedBox(height: 3.h),
              CustomWidgets.customText(
                "We'll show their details here once they're on the way.",
                11.sp,
                Consonants.greyColor,
                FontWeight.w500,
                maxLines: 2,
              ),
            ],
          ),
        ),
        _phaseChip(),
      ],
    );
  }

  Widget _driverDetails(RideDetails ride, DriverInfo driver) {
    final carInfo = driver.carInfo?.trim() ?? '';

    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 52.w,
              height: 52.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Consonants.primaryColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Consonants.whiteColor,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Consonants.primaryColor.withValues(alpha: 0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                driver.initial,
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
                          driver.displayName,
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
                          driver.ratingLabel,
                          11.sp,
                          Consonants.greyColor,
                          FontWeight.w700,
                          maxLines: 1,
                        ),
                      ),
                      if (carInfo.isNotEmpty) ...[
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
                            carInfo,
                            11.sp,
                            Consonants.greyColor,
                            FontWeight.w600,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            _phaseChip(),
          ],
        ),
        if (carInfo.isNotEmpty) ...[
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
                child: CustomWidgets.customText(
                  carInfo,
                  12.sp,
                  Consonants.boldTextColor,
                  FontWeight.w800,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ],
        SizedBox(height: 14.h),
        // Message the driver, and call them directly when a phone is on file.
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _openChat(ride),
                child: Container(
                  height: 46.h,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: Consonants.primaryColor.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded,
                          size: 16.sp, color: Consonants.whiteColor),
                      SizedBox(width: 8.w),
                      CustomWidgets.customText("Message driver", 13.sp,
                          Consonants.whiteColor, FontWeight.w800),
                    ],
                  ),
                ),
              ),
            ),
            if ((ride.driver?.phone ?? '').trim().isNotEmpty) ...[
              SizedBox(width: 10.w),
              GestureDetector(
                onTap: () => _callDriver(ride.driver!.phone!),
                child: Container(
                  height: 46.h,
                  width: 46.h,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Consonants.primaryGreenColor,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(Icons.call_rounded,
                      size: 20.sp, color: const Color(0xff15803D)),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Dial the driver's phone (only shown when a number is on file).
  Future<void> _callDriver(String phone) async {
    await _launch(Uri(scheme: 'tel', path: phone.trim()),
        fallback: "Couldn't start the call");
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

  void _quickActionSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(CustomWidgets.customSuccessSnackBar(message));
  }

  /// Cash-payment prompt: what this rider owes the driver, in cash. Payment is
  /// settled in person; the driver confirms collection at the end of the trip.
  Widget _cashPaymentHint(RideDetails ride) {
    final fare = ride.fare!;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xffF0FDF4),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xffBBF7D0)),
      ),
      child: Row(
        children: [
          Icon(Icons.payments_rounded,
              size: 20.sp, color: const Color(0xff15803D)),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomWidgets.customText(
                  "Pay ${fare.format(fare.perRider)} in cash",
                  13.sp,
                  const Color(0xff15803D),
                  FontWeight.w800,
                  maxLines: 1,
                ),
                SizedBox(height: 2.h),
                CustomWidgets.customText(
                  "Hand it to your driver at drop-off.",
                  11.sp,
                  Consonants.greyColor,
                  FontWeight.w500,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tripStrip(RideDetails ride, LatLng pickup, LatLng drop) {
    final fare = ride.fare;
    final fareValue = fare != null ? fare.format(fare.perRider) : "—";

    return Consumer(
      builder: (context, ref, _) {
        // Live ETA: measure from the driver's CURRENT position to the point
        // that matters now — the pickup while they're on the way, the drop
        // once the trip is rolling. Updates as the driver moves. Falls back to
        // the static pickup→drop route until the driver's location is known.
        final tracking = ref
            .watch(rideTrackingProvider(RideTrackArgs(ride.id, 'PASSENGER')))
            .asData
            ?.value;
        final driverPos = tracking?.driver?.position;
        // With a live driver fix: measure from the driver to the point that
        // matters now (pickup while en route, drop once rolling). WITHOUT one:
        // fall back to the whole pickup→drop trip route — never pickup→pickup,
        // which would show a meaningless "0.0 km / 0 min".
        final LatLng origin;
        final LatLng target;
        if (driverPos != null) {
          // Round to ~110 m so the route only refetches on meaningful movement.
          origin = LatLng((driverPos.latitude * 1000).roundToDouble() / 1000,
              (driverPos.longitude * 1000).roundToDouble() / 1000);
          target = _phase == _RidePhase.inTransit ? drop : pickup;
        } else {
          origin = pickup;
          target = drop;
        }

        String distanceValue = "—";
        String durationValue = "—";
        final async = ref.watch(directionsProvider(
          DirectionsRequest(origin: origin, destination: target),
        ));
        async.whenData((r) {
          distanceValue = "${r.distanceKm.toStringAsFixed(1)} km";
          durationValue = "${r.durationMinutes} min";
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
                  value: distanceValue,
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
                  value: durationValue,
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
                  value: fareValue,
                  label: "Fare",
                  accent: Consonants.primaryColor,
                ),
              ),
            ],
          ),
        );
      },
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

  Widget _stickyCta(RideDetails ride, double bottomInset) {
    // The passenger doesn't drive the trip — the driver does. So before the
    // trip moves the only real action is cancelling; once it's underway
    // (STARTED) we show a passive status instead of a fake button.
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
      child: canCancel
          ? GestureDetector(
              onTap: _cancelling ? null : () => _confirmCancel(ride),
              child: Container(
                height: 54.h,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xffFEE2E2),
                  borderRadius: BorderRadius.circular(40.r),
                  border: Border.all(color: const Color(0xffFCA5A5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.close_rounded,
                        size: 20.sp, color: const Color(0xffEF4444)),
                    SizedBox(width: 8.w),
                    CustomWidgets.customText(
                      _cancelling ? "Cancelling…" : "Cancel ride",
                      14.sp,
                      const Color(0xffEF4444),
                      FontWeight.w800,
                    ),
                  ],
                ),
              ),
            )
          : Container(
              height: 54.h,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Consonants.lightBlueColor,
                borderRadius: BorderRadius.circular(40.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car_filled_rounded,
                      size: 18.sp, color: Consonants.primaryColor),
                  SizedBox(width: 8.w),
                  Flexible(
                    child: CustomWidgets.customText(
                      "Trip in progress — enjoy your ride",
                      13.sp,
                      Consonants.primaryColor,
                      FontWeight.w700,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
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

  Widget _emptyState() {
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
          ],
        ),
      ),
    );
  }
}

// The active-trip driver/route/fare now come from the real RideDetails
// (via passengerActiveRideProvider) — the old hardcoded _kSampleDriver and
// address constants were removed. The active-trip map is the shared
// LiveTrackingMap (real-time car / person markers).
