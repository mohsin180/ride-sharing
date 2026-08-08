import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/directionsProvider.dart';
import 'package:ride_sharing/provider/passengerActiveRideProvider.dart';
import 'package:ride_sharing/provider/providers.dart';
import 'package:ride_sharing/provider/rideTrackingProvider.dart';
import 'package:ride_sharing/view/bottomNavbar.dart'
    show bottomNavIndexProvider;
import 'package:ride_sharing/view/driverScreens/driverChatDetail.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
import 'package:ride_sharing/widgets/consonants/jwtUtils.dart';
import 'package:ride_sharing/widgets/consonants/tokenStorage.dart';
import 'package:ride_sharing/widgets/custom/appComponents.dart';
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

enum _RidePhase { driverEnRoute, driverArrived, inTransit, arrived }

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
      barrierColor: Consonants.scrim,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Consonants.surface,
          insetPadding: EdgeInsets.symmetric(horizontal: 32.w),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Consonants.rHero.r),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(22.w, 26.h, 22.w, 20.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60.w,
                  height: 60.w,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Consonants.dangerWash,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cancel_outlined,
                    size: 26.sp,
                    color: Consonants.danger,
                  ),
                ),
                SizedBox(height: 18.h),
                Text(
                  "Cancel ride?",
                  style: AppText.sectionHeading().copyWith(fontSize: 19.sp),
                ),
                SizedBox(height: 8.h),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.paragraph(
                    color: feeApplies
                        ? Consonants.danger
                        : Consonants.textMuted,
                  ).copyWith(fontSize: 15.sp),
                ),
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: "Keep ride",
                        kind: AppButtonKind.neutral,
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                      ),
                    ),
                    SizedBox(width: Consonants.gapButtons.w),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(dialogCtx).pop();
                          _cancelRide(ride);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: 17.h,
                            horizontal: 12.w,
                          ),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Consonants.danger,
                            borderRadius: BorderRadius.circular(
                              Consonants.rButton.r,
                            ),
                          ),
                          child: Text(
                            "Cancel ride",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.button(
                              color: Consonants.surface,
                            ).copyWith(fontSize: 16.sp),
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
    await _launch(
      Uri(scheme: 'tel', path: '1122'),
      fallback: "Couldn't reach emergency services",
    );
  }

  /// Opens the ride's group chat — same `DriverChatDetail` screen the
  /// Messages tab pushes, keyed by the ride id.
  void _openChat(RideDetails ride) {
    final driver = ride.driver;
    final title = driver != null && driver.displayName.trim().isNotEmpty
        ? driver.displayName
        : "Ride chat";
    final members = driver != null
        ? [ChatMember(initial: driver.initial, color: Consonants.indigo)]
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
      // Launch directly — canLaunchUrl false-negatives on Android 11+ unless
      // every scheme is declared in the manifest; launchUrl reports failure.
      if (await launchUrl(uri, mode: mode)) {
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
    ref.listen<AsyncValue<List<RideDetails>>>(passengerActiveRideProvider, (
      prev,
      next,
    ) {
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
      backgroundColor: Consonants.canvas,
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
          await ref
              .read(rideServiceProvider)
              .rateCoPassenger(ride.id, c.id, stars);
        } catch (_) {}
      }
    }
  }

  // ─── Co-riders (matches the driver's remaining-passengers section) ──
  Widget _coRidersHeader(int count) {
    return AppSectionHeading(
      label: "Co-riders",
      trailing: Text(
        "$count",
        style: AppText.caption().copyWith(fontSize: 13.sp),
      ),
    );
  }

  Widget _coRiderTile(RideCoPassenger c) {
    final name = c.name.trim().isEmpty ? "Passenger" : c.name.trim();
    final rating = (c.rating != null && c.rating! > 0)
        ? c.rating!.toStringAsFixed(1)
        : "New";
    return AppListRow(
      icon: Icons.person_outline_rounded,
      title: name,
      meta: "$rating rating",
      onTap: () => _showCoRiderDetails(c),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 22.sp,
        color: Consonants.textMuted,
      ),
    );
  }

  void _showCoRiderDetails(RideCoPassenger c) {
    final name = c.name.trim().isEmpty ? "Passenger" : c.name.trim();
    final rating = (c.rating != null && c.rating! > 0)
        ? c.rating!.toStringAsFixed(1)
        : "New";
    showAppSheet<void>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHeader(title: "Co-rider"),
          SizedBox(height: 20.h),
          Row(
            children: [
              Container(
                width: 56.w,
                height: 56.w,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Consonants.indigoWash,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  name[0].toUpperCase(),
                  style: AppText.screenTitle(
                    color: Consonants.indigo,
                  ).copyWith(fontSize: 22.sp),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.sectionHeading().copyWith(fontSize: 19.sp),
                    ),
                    SizedBox(height: 5.h),
                    Row(
                      children: [
                        Icon(
                          Icons.star_outline_rounded,
                          size: 14.sp,
                          color: Consonants.textMuted,
                        ),
                        SizedBox(width: 5.w),
                        Text(
                          "$rating  ·  Sharing this ride",
                          style: AppText.caption().copyWith(fontSize: 13.sp),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Active ride layout ─────────────────────────────────

  Widget _activeRide(RideDetails ride) {
    // Derive the passenger-facing phase from the authoritative ride status,
    // so the banner/chip below track what the driver actually did.
    _phase = _phaseFor(ride.status);
    final hasCoords =
        ride.pickupLat != null &&
        ride.pickupLng != null &&
        ride.dropLat != null &&
        ride.dropLng != null;
    final pickupLL = hasCoords
        ? LatLng(ride.pickupLat!, ride.pickupLng!)
        : _pickup;
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
                  // In transit, this rider moves WITH the car — let their own
                  // GPS keep consuming the route if the driver's feed drops.
                  consumeWithMyPosition: _phase == _RidePhase.inTransit,
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
              color: Consonants.canvas,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(Consonants.rSheet.r),
              ),
              boxShadow: Consonants.sheetLift,
            ),
            child: Column(
              children: [
                SizedBox(height: 12.h),
                Container(
                  width: 44.w,
                  height: 5.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6D6E2),
                    borderRadius: BorderRadius.circular(Consonants.rPill.r),
                  ),
                ),
                SizedBox(height: 18.h),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: Consonants.gutter.w,
                    ),
                    children: [
                      // Below-map layout mirrors the driver's active-ride
                      // cockpit: status band → focus card → trip strip →
                      // co-riders list. (The full route is on the map now, so
                      // the old text route card is dropped — same as the driver.)
                      _statusBand(),
                      SizedBox(height: Consonants.gapTiles.h),
                      _tripStrip(ride, pickupLL, dropLL),
                      SizedBox(height: Consonants.gapTiles.h),
                      _driverCard(ride),
                      if (ride.fare != null) ...[
                        SizedBox(height: Consonants.gapTiles.h),
                        _cashPaymentHint(ride),
                      ],
                      if (ride.coPassengers.isNotEmpty) ...[
                        SizedBox(height: 26.h),
                        _coRidersHeader(ride.coPassengers.length),
                        for (int i = 0; i < ride.coPassengers.length; i++) ...[
                          _coRiderTile(ride.coPassengers[i]),
                          if (i != ride.coPassengers.length - 1)
                            const AppDivider(),
                        ],
                      ],
                      SizedBox(height: 22.h),
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
                      horizontal: 14.w,
                      vertical: 9.h,
                    ),
                    decoration: BoxDecoration(
                      color: Consonants.surface,
                      borderRadius: BorderRadius.circular(Consonants.rPill.r),
                      boxShadow: Consonants.cardLift,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.directions_car_outlined,
                          size: 15.sp,
                          color: Consonants.iconInk,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          "Live Trip",
                          style: AppText.navLabel(
                            color: Consonants.iconInk,
                          ).copyWith(fontSize: 12.5.sp),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _circleIconButton(
                    icon: Icons.shield_outlined,
                    iconColor: Consonants.danger,
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
        decoration: const BoxDecoration(
          color: Consonants.surface,
          shape: BoxShape.circle,
          boxShadow: Consonants.cardLift,
        ),
        child: Icon(icon, size: 20.sp, color: iconColor ?? Consonants.iconInk),
      ),
    );
  }

  Widget _statusBand() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: Consonants.indigoWash,
        borderRadius: BorderRadius.circular(Consonants.rCard.r),
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
                  color: Consonants.indigo.withValues(
                    alpha: 0.45 + 0.55 * _pulse.value,
                  ),
                  shape: BoxShape.circle,
                ),
              );
            },
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              _statusLine,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.rowLabel(
                color: Consonants.headingInk,
              ).copyWith(fontSize: 15.sp, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _driverCard(RideDetails ride) {
    final driver = ride.driver;
    return AppCard(
      padding: EdgeInsets.all(18.w),
      child: driver == null ? _driverPending() : _driverDetails(ride, driver),
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
          decoration: const BoxDecoration(
            color: Consonants.indigoWash,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.person_search_outlined,
            size: 24.sp,
            color: Consonants.indigo,
          ),
        ),
        SizedBox(width: 14.w),
        Expanded(
          child: Text(
            "Driver assigned soon",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.rowLabel(
              color: Consonants.headingInk,
            ).copyWith(fontSize: 16.sp, fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(width: 10.w),
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
              decoration: const BoxDecoration(
                color: Consonants.indigoWash,
                shape: BoxShape.circle,
              ),
              child: Text(
                driver.initial,
                style: AppText.amount(
                  color: Consonants.indigo,
                ).copyWith(fontSize: 20.sp),
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          driver.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.rowLabel(color: Consonants.headingInk)
                              .copyWith(
                                fontSize: 16.5.sp,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      SizedBox(width: 5.w),
                      Icon(
                        Icons.verified_outlined,
                        size: 15.sp,
                        color: Consonants.iconInk,
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Icon(
                        Icons.star_outline_rounded,
                        size: 14.sp,
                        color: Consonants.textMuted,
                      ),
                      SizedBox(width: 4.w),
                      Flexible(
                        child: Text(
                          driver.ratingLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption().copyWith(fontSize: 12.5.sp),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            _phaseChip(),
          ],
        ),
        if (carInfo.isNotEmpty) ...[
          SizedBox(height: 16.h),
          const AppDivider(),
          SizedBox(height: 16.h),
          Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Consonants.chipBg,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.directions_car_outlined,
                  size: 19.sp,
                  color: Consonants.iconInk,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  carInfo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.rowLabel().copyWith(fontSize: 15.5.sp),
                ),
              ),
            ],
          ),
        ],
        SizedBox(height: 18.h),
        // Message the driver, and call them directly when a phone is on file.
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: "Message driver",
                icon: Icons.chat_bubble_outline_rounded,
                onPressed: () => _openChat(ride),
              ),
            ),
            if ((ride.driver?.phone ?? '').trim().isNotEmpty) ...[
              SizedBox(width: Consonants.gapButtons.w),
              GestureDetector(
                onTap: () => _callDriver(ride.driver!.phone!),
                child: Container(
                  height: 56.h,
                  width: 56.h,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Consonants.chipBg,
                    borderRadius: BorderRadius.circular(Consonants.rButton.r),
                  ),
                  child: Icon(
                    Icons.call_outlined,
                    size: 21.sp,
                    color: Consonants.iconInk,
                  ),
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
    await _launch(
      Uri(scheme: 'tel', path: phone.trim()),
      fallback: "Couldn't start the call",
    );
  }

  Widget _phaseChip() {
    final label = switch (_phase) {
      _RidePhase.driverEnRoute => "On the way",
      _RidePhase.driverArrived => "Arrived",
      _RidePhase.inTransit => "In transit",
      _RidePhase.arrived => "Reached",
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Consonants.chipBg,
        borderRadius: BorderRadius.circular(Consonants.rPill.r),
      ),
      child: Text(
        label,
        style: AppText.navLabel(
          color: Consonants.iconInk,
        ).copyWith(fontSize: 12.sp),
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
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: Consonants.chipBg,
        borderRadius: BorderRadius.circular(Consonants.rCard.r),
      ),
      child: Row(
        children: [
          Icon(Icons.payments_outlined, size: 20.sp, color: Consonants.iconInk),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              "Pay ${fare.format(fare.perRider)} in cash",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.rowLabel(
                color: Consonants.headingInk,
              ).copyWith(fontSize: 15.sp, fontWeight: FontWeight.w600),
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
        String distanceValue = "—";
        String durationValue = "—";
        if (driverPos != null) {
          // Live: from the driver's position to the point that matters now.
          // Round to ~110 m so the route only refetches on real movement.
          final origin = LatLng(
            (driverPos.latitude * 1000).roundToDouble() / 1000,
            (driverPos.longitude * 1000).roundToDouble() / 1000,
          );
          final target = _phase == _RidePhase.inTransit ? drop : pickup;
          ref
              .watch(
                directionsProvider(
                  DirectionsRequest(origin: origin, destination: target),
                ),
              )
              .whenData((r) {
                distanceValue = "${r.distanceKm.toStringAsFixed(1)} km";
                durationValue = "${r.durationMinutes} min";
              });
        } else if (ride.tripDistanceKm != null) {
          // No live fix yet: show the FULL shared trip (through every rider's
          // stops, recomputed by the backend) — grows as co-riders join.
          distanceValue = "${ride.tripDistanceKm!.toStringAsFixed(1)} km";
          durationValue = ride.tripDurationMin != null
              ? "${ride.tripDurationMin} min"
              : "—";
        } else {
          ref
              .watch(
                directionsProvider(
                  DirectionsRequest(origin: pickup, destination: drop),
                ),
              )
              .whenData((r) {
                distanceValue = "${r.distanceKm.toStringAsFixed(1)} km";
                durationValue = "${r.durationMinutes} min";
              });
        }

        return HeroSurface(
          padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 22.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Your fare",
                style: AppText.caption(
                  color: const Color(0xCCFFFFFF),
                ).copyWith(fontSize: 13.sp),
              ),
              SizedBox(height: 8.h),
              Text(
                fareValue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.figure(
                  color: Consonants.surface,
                ).copyWith(fontSize: 36.sp),
              ),
              SizedBox(height: 18.h),
              Row(
                children: [
                  HeroChip(
                    label: distanceValue,
                    icon: Icons.straighten_rounded,
                  ),
                  SizedBox(width: 8.w),
                  HeroChip(
                    label: durationValue,
                    icon: Icons.access_time_rounded,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _safetyTile() {
    return AppCard(
      onTap: () => _quickActionSnack("Live location shared with your contacts"),
      padding: EdgeInsets.all(16.w),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Consonants.chipBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shield_outlined,
              size: 20.sp,
              color: Consonants.iconInk,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Ride safely",
                  style: AppText.rowLabel().copyWith(fontSize: 16.sp),
                ),
                SizedBox(height: 3.h),
                Text(
                  "Verify the vehicle plate before boarding",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption().copyWith(fontSize: 12.5.sp),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 22.sp,
            color: Consonants.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _stickyCta(RideDetails ride, double bottomInset) {
    // The passenger doesn't drive the trip — the driver does. So before the
    // trip moves the only real action is cancelling; once it's underway
    // (STARTED) we show a passive status instead of a fake button.
    final canCancel =
        _phase == _RidePhase.driverEnRoute ||
        _phase == _RidePhase.driverArrived;
    return Padding(
      // The floating nav sits over this panel, so the action reserves the
      // system's nav clearance rather than hiding underneath it.
      padding: EdgeInsets.fromLTRB(
        Consonants.gutter.w,
        12.h,
        Consonants.gutter.w,
        Consonants.navClearance.h + bottomInset,
      ),
      child: canCancel
          ? GestureDetector(
              onTap: _cancelling ? null : () => _confirmCancel(ride),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 17.h, horizontal: 20.w),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Consonants.rButton.r),
                  border: Border.all(color: Consonants.danger, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.close_rounded,
                      size: 19.sp,
                      color: Consonants.danger,
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      _cancelling ? "Cancelling…" : "Cancel ride",
                      style: AppText.button(
                        color: Consonants.danger,
                      ).copyWith(fontSize: 17.5.sp),
                    ),
                  ],
                ),
              ),
            )
          : Container(
              padding: EdgeInsets.symmetric(vertical: 17.h, horizontal: 20.w),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Consonants.indigoWash,
                borderRadius: BorderRadius.circular(Consonants.rButton.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.directions_car_outlined,
                    size: 19.sp,
                    color: Consonants.indigo,
                  ),
                  SizedBox(width: 10.w),
                  Flexible(
                    child: Text(
                      "Trip in progress",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.button(
                        color: Consonants.indigo,
                      ).copyWith(fontSize: 16.sp),
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
      color: Consonants.indigoWash,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 34.sp, color: Consonants.indigo),
          SizedBox(height: 10.h),
          Text(
            "Loading map…",
            style: AppText.caption().copyWith(fontSize: 13.sp),
          ),
        ],
      ),
    );
  }

  // ─── Empty state ────────────────────────────────────────

  Widget _emptyState() {
    return SafeArea(
      bottom: false,
      // Explicit full width: this tab is reached through a Stack, which hands
      // its children loose constraints, so the centred column would otherwise
      // shrink to its widest child and sit against the left gutter.
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Consonants.gutter.w,
            0,
            Consonants.gutter.w,
            Consonants.navClearance.h,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96.w,
                height: 96.w,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Consonants.indigoWash,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.route_outlined,
                  size: 40.sp,
                  color: Consonants.indigo,
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                "No active ride right now",
                style: AppText.screenTitle().copyWith(fontSize: 22.sp),
              ),
              SizedBox(height: 28.h),
              AppButton(
                label: "Book a Ride",
                icon: Icons.directions_car_outlined,
                expand: false,
                onPressed: () => ref
                    .read(bottomNavIndexProvider.notifier)
                    .select(_kRideTabIndex),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
