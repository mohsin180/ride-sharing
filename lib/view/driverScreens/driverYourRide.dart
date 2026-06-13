import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/driverActiveRideProvider.dart';
import 'package:ride_sharing/provider/driverFeedProvider.dart';
import 'package:ride_sharing/provider/providers.dart';
import 'package:ride_sharing/widgets/custom/liveTrackingMap.dart';
import 'package:ride_sharing/view/bottomNavbar.dart' show bottomNavIndexProvider;
import 'package:ride_sharing/view/driverScreens/driverViewDetails.dart';
import 'package:ride_sharing/widgets/consonants/apiException.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';
import 'package:ride_sharing/widgets/custom/ratingSheet.dart';

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
/// The active trip is sourced from `driverActiveRideProvider`
/// (GET /api/v1/rides/driver/active). The per-passenger pickup/drop
/// ordering (`_currentIndex`, `_phase`) is local UI state, seeded once
/// per ride; advancing to the final drop calls `completeRide`.
class Driveryourride extends ConsumerStatefulWidget {
  const Driveryourride({super.key});

  @override
  ConsumerState<Driveryourride> createState() => _DriveryourrideState();
}

enum _RidePhase {
  headingToPickup,
  arrivedAtPickup,
  inTransitNextPickup,
  inTransitDropoff,
  lastDropoff,
}

class _DriveryourrideState extends ConsumerState<Driveryourride>
    with TickerProviderStateMixin {
  // Lahore-area fallback used only when a ride has no usable coordinates.
  static const _fallbackPickup = LatLng(31.5142, 74.3625);
  static const _fallbackDrop = LatLng(31.5290, 74.3500);

  List<Passenger> _passengers = const [];
  int _currentIndex = 0;
  _RidePhase _phase = _RidePhase.headingToPickup;

  /// Id of the ride the local phase machine is currently seeded from, so
  /// a provider refresh (e.g. after auto-start) doesn't wipe in-trip
  /// progress. Null when no ride is loaded.
  String? _loadedRideId;

  /// The latest active ride detail — kept so the post-trip flow can rate
  /// each passenger by their real userId after completion.
  RideDetails? _ride;

  /// True while the complete-trip request is in flight.
  bool _completing = false;

  /// True once the user has selected the "Your Ride" tab at least once.
  /// While false the map area renders a tinted placeholder, so the
  /// expensive map platform view is not created on the same frame that
  /// the bottom navbar mounts.
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

  // ─── Seeding from the backend ride ──────────────────────

  /// Seed the local phase machine the first time a given ride appears.
  /// Re-runs only when the active ride id changes, so refreshes mid-trip
  /// preserve pickup/drop progress.
  void _seedIfNeeded(RideDetails ride) {
    _ride = ride;
    if (_loadedRideId == ride.id) return;
    _loadedRideId = ride.id;
    _passengers = _passengersFrom(ride);
    _currentIndex = 0;
    _phase = _RidePhase.headingToPickup;
    // An ACCEPTED ride the driver is now actively viewing should move to
    // STARTED so the backend lifecycle tracks the cockpit.
    if (ride.status == RideStatus.accepted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureStarted(ride.id));
    }
  }

  List<Passenger> _passengersFrom(RideDetails ride) {
    const palette = [
      Color(0xff60A5FA),
      Color(0xffF472B6),
      Color(0xffFBBF24),
      Color(0xff34D399),
      Color(0xffA78BFA),
    ];
    final fare = ride.fare;
    final fareLabel = fare != null ? fare.format(fare.perRider) : "Rs —";

    String nameOr(String raw) => raw.trim().isEmpty ? "Passenger" : raw.trim();

    final list = <Passenger>[];
    final hostName = nameOr(ride.host.name);
    list.add(Passenger(
      name: hostName,
      initial: hostName[0].toUpperCase(),
      avatarColor: palette[0],
      rating: ride.host.rating != null
          ? ride.host.rating!.toStringAsFixed(1)
          : "—",
      pickup: ride.pickup,
      drop: ride.drop,
      distanceToPickup: "—",
      etaToPickup: "—",
      fare: fareLabel,
      seats: 1,
      status: PickupStatus.current,
      isHost: true,
    ));
    for (int i = 0; i < ride.coPassengers.length; i++) {
      final c = ride.coPassengers[i];
      final n = nameOr(c.name);
      list.add(Passenger(
        name: n,
        initial: n[0].toUpperCase(),
        avatarColor: palette[(i + 1) % palette.length],
        rating: c.rating != null ? c.rating!.toStringAsFixed(1) : "—",
        pickup: ride.pickup,
        drop: ride.drop,
        distanceToPickup: "—",
        etaToPickup: "—",
        fare: fareLabel,
        seats: 1,
        status: PickupStatus.upcoming,
      ));
    }
    return list;
  }

  Future<void> _ensureStarted(String id) async {
    try {
      await ref.read(rideServiceProvider).startRide(id);
      ref.invalidate(driverActiveRideProvider);
    } catch (_) {
      // Already STARTED or a transient error — the cockpit still works
      // and complete will re-validate the status, so swallow it.
    }
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

  /// All riders dropped — close out the ride on the backend
  /// (STARTED → COMPLETED), prompt the driver to rate each passenger, then
  /// let the active-ride list empty out to the tab's empty state.
  Future<void> _completeTrip() async {
    final id = _loadedRideId;
    final ride = _ride;
    if (id == null || _completing) return;
    setState(() => _completing = true);
    try {
      await ref.read(rideServiceProvider).completeRide(id);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _completing = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(CustomWidgets.customErrorSnackBar(e.message));
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _completing = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          CustomWidgets.customErrorSnackBar("Couldn't complete trip"),
        );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(CustomWidgets.customSuccessSnackBar("Trip completed"));

    // Rate each passenger (best-effort, sequential) before clearing the
    // trip. The ride is COMPLETED now, so rate-passenger is permitted.
    if (ride != null) {
      await _ratePassengers(id, ride);
    }

    ref.invalidate(driverActiveRideProvider);
    ref.invalidate(driverFeedProvider);
    if (mounted) setState(() => _completing = false);
  }

  /// Walk the driver through rating the host + each co-passenger. Skipping
  /// a passenger (or a failed submit) just moves on — rating is optional.
  Future<void> _ratePassengers(String rideId, RideDetails ride) async {
    final people = <({String id, String name})>[
      (id: ride.host.id, name: ride.host.name),
      ...ride.coPassengers.map((c) => (id: c.id, name: c.name)),
    ];
    for (final p in people) {
      if (!mounted) return;
      if (p.id.isEmpty) continue;
      final name = p.name.trim().isEmpty ? "Passenger" : p.name.trim();
      final stars = await showRatingSheet(
        context: context,
        title: "Rate $name",
        subtitle: "How was your passenger this trip?",
        avatarInitial: name[0].toUpperCase(),
      );
      if (stars == null) continue;
      try {
        await ref.read(rideServiceProvider).ratePassenger(rideId, p.id, stars);
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              CustomWidgets.customSuccessSnackBar("Rated $name"),
            );
        }
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(CustomWidgets.customErrorSnackBar(e.message));
        }
      } catch (_) {
        // Best-effort — keep going to the next passenger.
      }
    }
  }

  /// The driver backs out of the trip. The ride is re-opened for another
  /// driver (it does NOT cancel the passengers' trip). Confirms first.
  Future<void> _dropRide() async {
    final id = _loadedRideId;
    if (id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Drop this ride?"),
        content: const Text(
          "It'll be re-opened for another driver. Your passengers keep their trip.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Keep driving"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Drop ride"),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await ref.read(rideServiceProvider).driverCancelRide(id);
      ref.invalidate(driverActiveRideProvider);
      ref.invalidate(driverFeedProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(CustomWidgets.customSuccessSnackBar("Ride dropped"));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(CustomWidgets.customErrorSnackBar(e.message));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(CustomWidgets.customErrorSnackBar("Couldn't drop ride"));
    }
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
    // Flip _mapMounted on the first frame after the tab becomes selected.
    // This keeps the map out of the widget tree until the user actually
    // views this tab — avoids initializing the platform view inside the
    // IndexedStack on app launch.
    final selectedTab = ref.watch(bottomNavIndexProvider);
    if (!_mapMounted && selectedTab == _kYourRideTabIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_mapMounted) {
          setState(() => _mapMounted = true);
        }
      });
    }

    final asyncRides = ref.watch(driverActiveRideProvider);

    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      body: asyncRides.when(
        loading: () => _loadingState(),
        error: (e, _) => _emptyState(
          message: e is ApiException
              ? e.message
              : "Couldn't load your active ride",
        ),
        data: (rides) {
          if (rides.isEmpty) {
            _loadedRideId = null;
            return _emptyState();
          }
          final ride = rides.first;
          _seedIfNeeded(ride);
          return _activeRide(ride);
        },
      ),
    );
  }

  // ─── Active ride layout ─────────────────────────────────

  Widget _activeRide(RideDetails ride) {
    // Real route coordinates from the ride; fall back to the Lahore demo
    // points only when the ride is missing usable lat/lng.
    final hasCoords = ride.pickupLat != null &&
        ride.pickupLng != null &&
        ride.dropLat != null &&
        ride.dropLng != null;
    final pickupLL = hasCoords
        ? LatLng(ride.pickupLat!, ride.pickupLng!)
        : _fallbackPickup;
    final dropLL =
        hasCoords ? LatLng(ride.dropLat!, ride.dropLng!) : _fallbackDrop;

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
              ? LiveTrackingMap(
                  rideId: ride.id,
                  pickup: pickupLL,
                  drop: dropLL,
                  myRole: 'DRIVER',
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
                    onTap: _dropRide,
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

  // ─── Loading state ──────────────────────────────────────

  Widget _loadingState() {
    return const SafeArea(
      child: Center(child: CircularProgressIndicator()),
    );
  }

  // ─── Empty state ────────────────────────────────────────

  Widget _emptyState({String? message}) {
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
              message ?? "Accepted rides from the Rides tab will appear here",
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

// The active-ride map is now the shared LiveTrackingMap (real-time car /
// person markers); the old static _RouteMap was removed.
