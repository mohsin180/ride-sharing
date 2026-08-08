import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/directionsProvider.dart';
import 'package:ride_sharing/provider/rideTrackingProvider.dart';
import 'package:ride_sharing/provider/driverActiveRideProvider.dart';
import 'package:ride_sharing/provider/driverEarningsProvider.dart';
import 'package:ride_sharing/provider/driverFeedProvider.dart';
import 'package:ride_sharing/provider/providers.dart';
import 'package:ride_sharing/widgets/custom/liveTrackingMap.dart';
import 'package:ride_sharing/view/bottomNavbar.dart'
    show bottomNavIndexProvider;
import 'package:ride_sharing/view/driverScreens/driverChatDetail.dart';
import 'package:ride_sharing/view/driverScreens/driverViewDetails.dart';
import 'package:ride_sharing/widgets/consonants/apiException.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/appComponents.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';
import 'package:ride_sharing/widgets/custom/ratingSheet.dart';
import 'package:url_launcher/url_launcher.dart';

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
  /// preserve pickup/drop progress. The starting phase is derived from the
  /// ride's real backend status, so re-opening the cockpit (or an app
  /// restart) resumes at the correct step instead of snapping back to
  /// "heading to pickup".
  void _seedIfNeeded(RideDetails ride) {
    _ride = ride;
    if (_loadedRideId == ride.id) return;
    _loadedRideId = ride.id;
    _passengers = _passengersFrom(ride);
    _currentIndex = 0;
    switch (ride.status) {
      case RideStatus.arrived:
        // Driver already signalled arrival — waiting to start.
        _phase = _RidePhase.arrivedAtPickup;
        break;
      case RideStatus.started:
        // Trip already underway. Each rider's real picked/dropped status was
        // seeded from the backend in _passengersFrom, so just re-derive the
        // phase from it — restart-safe, no more forcing the first rider.
        if (_passengers.every((p) => p.status == PickupStatus.upcoming) &&
            _passengers.isNotEmpty) {
          // No one marked yet (started straight through) — treat first as here.
          _passengers[0] = _passengers[0].copyWith(
            status: PickupStatus.current,
          );
        }
        _recomputePhase();
        break;
      case RideStatus.accepted:
      default:
        _phase = _RidePhase.headingToPickup;
    }
  }

  List<Passenger> _passengersFrom(RideDetails ride) {
    // Avatar fills stay inside the brand ramp — two hues, no rainbow.
    const palette = [
      Consonants.indigo,
      Consonants.violet,
      Consonants.indigoMid,
      Color(0xff6E4BC9),
      Color(0xff8A5BE0),
    ];
    final fare = ride.fare;
    // Weighted pricing: each rider's own share (leg × seats) from the
    // backend; fall back to the average only when a share is missing.
    String shareLabel(double? share) => share != null
        ? (fare?.format(share) ?? "Rs ${share.round()}")
        : (fare != null ? fare.format(fare.perRider) : "Rs —");

    String nameOr(String raw) => raw.trim().isEmpty ? "Passenger" : raw.trim();

    final list = <Passenger>[];
    final hostName = nameOr(ride.host.name);
    list.add(
      Passenger(
        userId: ride.host.id,
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
        fare: shareLabel(ride.host.fareShare),
        seats: 1,
        status: _statusFromWire(ride.host.pickupStatus, isFirst: true),
        isHost: true,
        phone: ride.host.phone,
      ),
    );
    for (int i = 0; i < ride.coPassengers.length; i++) {
      final c = ride.coPassengers[i];
      final n = nameOr(c.name);
      list.add(
        Passenger(
          userId: c.id,
          name: n,
          initial: n[0].toUpperCase(),
          avatarColor: palette[(i + 1) % palette.length],
          rating: c.rating != null ? c.rating!.toStringAsFixed(1) : "—",
          pickup: ride.pickup,
          drop: ride.drop,
          distanceToPickup: "—",
          etaToPickup: "—",
          fare: shareLabel(c.fareShare),
          seats: 1,
          status: _statusFromWire(c.pickupStatus, isFirst: false),
          phone: c.phone,
        ),
      );
    }
    return list;
  }

  /// Map the backend per-rider status to the cockpit's local [PickupStatus],
  /// so re-opening the cockpit (or an app restart) resumes real progress.
  PickupStatus _statusFromWire(String? wire, {required bool isFirst}) {
    switch (wire) {
      case 'PICKED':
        return PickupStatus.picked;
      case 'DROPPED':
        return PickupStatus.dropped;
      case 'WAITING':
      default:
        return isFirst ? PickupStatus.current : PickupStatus.upcoming;
    }
  }

  /// True while an arrive/start transition request is in flight, so the CTA
  /// can't be double-fired.
  bool _advancing = false;

  /// Push the real backend transition for the current phase, returning true
  /// on success. Surfaces the error (and stays put) on failure so the driver
  /// isn't advanced past a step the server rejected.
  Future<bool> _pushTransition(Future<void> Function(String id) call) async {
    final id = _loadedRideId;
    if (id == null || _advancing) return false;
    setState(() => _advancing = true);
    try {
      await call(id);
      ref.invalidate(driverActiveRideProvider);
      return true;
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(CustomWidgets.customErrorSnackBar(e.message));
      }
      return false;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            CustomWidgets.customErrorSnackBar("Couldn't update the trip"),
          );
      }
      return false;
    } finally {
      if (mounted) setState(() => _advancing = false);
    }
  }

  // ─── Phase machine ───────────────────────────────────────

  Passenger get _focus => _passengers[_currentIndex];

  /// Only riders actually picked up (or already dropped) count as "handled".
  /// A rider still `current`/`upcoming` has NOT boarded yet — treating
  /// `current` as picked used to freeze the machine on a mid-trip restart.
  bool _isBoarded(Passenger p) =>
      p.status == PickupStatus.picked || p.status == PickupStatus.dropped;

  int get _pickedCount => _passengers.where(_isBoarded).length;

  /// Re-derive the right phase based on current passenger statuses.
  /// Called after every advance so the UI is always self-consistent.
  void _recomputePhase() {
    final allPicked = _passengers.every(_isBoarded);
    if (!allPicked) {
      // Next rider to pick up — either still `upcoming` or the current focus.
      final next = _passengers.indexWhere((p) => !_isBoarded(p));
      _currentIndex = next == -1 ? 0 : next;
      // First pickup reads as "Heading to pickup"; later ones as
      // "Heading to next pickup" so the copy matches naturally.
      _phase = _pickedCount == 0
          ? _RidePhase.headingToPickup
          : _RidePhase.inTransitNextPickup;
      return;
    }
    // All picked up — switch into drop-off cycle.
    final remainingDrops = _passengers
        .where((p) => p.status == PickupStatus.picked)
        .toList();
    final nextDropIdx = _passengers.indexWhere(
      (p) => p.status == PickupStatus.picked,
    );
    if (nextDropIdx == -1) return;
    _currentIndex = nextDropIdx;
    _phase = remainingDrops.length == 1
        ? _RidePhase.lastDropoff
        : _RidePhase.inTransitDropoff;
  }

  /// Persist a pickup / drop-off to the backend (best-effort — the local UI
  /// already advanced; a network hiccup shouldn't block the driver, and the
  /// status is re-seeded from the server on the next active-ride poll).
  void _persistPickup(Passenger p) {
    final id = _loadedRideId;
    if (id == null || p.userId.isEmpty) return;
    ref
        .read(rideServiceProvider)
        .markRiderPickedUp(id, p.userId)
        .catchError((_) {});
  }

  void _persistDropoff(Passenger p) {
    final id = _loadedRideId;
    if (id == null || p.userId.isEmpty) return;
    ref
        .read(rideServiceProvider)
        .markRiderDroppedOff(id, p.userId)
        .then((_) => ref.invalidate(driverEarningsProvider))
        .catchError((_) {});
  }

  Future<void> _advance() async {
    if (_advancing || _completing) return;
    switch (_phase) {
      case _RidePhase.headingToPickup:
        // Reached the pickup: ACCEPTED → ARRIVED on the backend so every
        // rider's screen flips to "driver has arrived".
        final ok = await _pushTransition(
          (id) => ref.read(rideServiceProvider).arriveRide(id),
        );
        if (!ok) return;
        setState(() => _phase = _RidePhase.arrivedAtPickup);
        break;
      case _RidePhase.arrivedAtPickup:
        // First rider boards: ARRIVED → STARTED. This is the one backend
        // transition for boarding; further pickups are per-rider events
        // within the STARTED trip, persisted below.
        final ok = await _pushTransition(
          (id) => ref.read(rideServiceProvider).startRide(id),
        );
        if (!ok) return;
        _persistPickup(_focus);
        setState(() {
          _passengers[_currentIndex] = _focus.copyWith(
            status: PickupStatus.picked,
          );
          _recomputePhase();
        });
        break;
      case _RidePhase.inTransitNextPickup:
        _persistPickup(_focus);
        setState(() {
          _passengers[_currentIndex] = _focus.copyWith(
            status: PickupStatus.picked,
          );
          _recomputePhase();
        });
        break;
      case _RidePhase.inTransitDropoff:
      case _RidePhase.lastDropoff:
        // Persist the drop — this settles that rider's cash on the backend.
        _persistDropoff(_focus);
        setState(() {
          _passengers[_currentIndex] = _focus.copyWith(
            status: PickupStatus.dropped,
          );
        });
        if (_passengers.every((p) => p.status == PickupStatus.dropped)) {
          _completeTrip();
        } else {
          setState(_recomputePhase);
        }
        break;
    }
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

    // Collect the cash fare from each rider (the ride is COMPLETED, so the
    // payment ledger now exists), then rate the passengers.
    await _collectPayments(id);
    if (ride != null && mounted) {
      await _ratePassengers(id, ride);
    }

    ref.invalidate(driverActiveRideProvider);
    ref.invalidate(driverFeedProvider);
    // Refresh the home dashboard earnings immediately now the ride is done.
    ref.invalidate(driverEarningsProvider);
    if (mounted) setState(() => _completing = false);
  }

  /// Show the cash-collection sheet: each rider's fare, tap to mark collected.
  /// Best-effort — a fetch failure just skips straight to ratings.
  Future<void> _collectPayments(String rideId) async {
    List<RidePaymentEntry> payments;
    try {
      payments = await ref.read(rideServiceProvider).getRidePayments(rideId);
    } catch (_) {
      return;
    }
    if (!mounted || payments.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CollectCashSheet(rideId: rideId, initial: payments),
    );
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
        avatarInitial: name[0].toUpperCase(),
      );
      if (stars == null) continue;
      try {
        await ref.read(rideServiceProvider).ratePassenger(rideId, p.id, stars);
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(CustomWidgets.customSuccessSnackBar("Rated $name"));
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
        backgroundColor: Consonants.surface,
        title: Text(
          "Drop this ride?",
          style: AppText.sectionHeading().copyWith(fontSize: 18.sp),
        ),
        content: Text(
          "It'll be re-opened for another driver. Your passengers keep their trip.",
          style: AppText.paragraph().copyWith(fontSize: 15.sp),
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
        // Live ETA/distance is shown in the trip strip below; keep the banner
        // clean instead of a hardcoded "ETA —".
        return "Heading to ${_focus.name.split(' ').first}'s pickup";
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
      backgroundColor: Consonants.canvas,
      body: asyncRides.when(
        // Keep the cockpit on screen during the 8s background poll instead of
        // flashing the loading state each refresh.
        skipLoadingOnReload: true,
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
    final hasCoords =
        ride.pickupLat != null &&
        ride.pickupLng != null &&
        ride.dropLat != null &&
        ride.dropLng != null;
    final pickupLL = hasCoords
        ? LatLng(ride.pickupLat!, ride.pickupLng!)
        : _fallbackPickup;
    final dropLL = hasCoords
        ? LatLng(ride.dropLat!, ride.dropLng!)
        : _fallbackDrop;

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
                  // Draw the full multi-stop route through every co-passenger
                  // pickup/drop in shortest order, not just host pickup→drop.
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
              // Canvas, not white — the cards inside are the white layer.
              color: Consonants.canvas,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(Consonants.rSheet.r),
                topRight: Radius.circular(Consonants.rSheet.r),
              ),
              boxShadow: Consonants.sheetLift,
            ),
            child: Column(
              children: [
                SizedBox(height: 10.h),
                Container(
                  width: 44.w,
                  height: 5.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6D6E2),
                    borderRadius: BorderRadius.circular(Consonants.rPill.r),
                  ),
                ),
                SizedBox(height: 14.h),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: Consonants.gutter.w,
                    ),
                    children: [
                      _statusBand(),
                      SizedBox(height: 16.h),
                      _focusCard(),
                      SizedBox(height: 16.h),
                      _tripStrip(pickupLL, dropLL),
                      if (remaining.isNotEmpty) ...[
                        SizedBox(height: 26.h),
                        _remainingHeader(remaining.length),
                        SizedBox(height: 4.h),
                        for (int i = 0; i < remaining.length; i++) ...[
                          _remainingTile(remaining[i]),
                          if (i != remaining.length - 1) const AppDivider(),
                        ],
                      ],
                      SizedBox(height: 20.h),
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
              padding: EdgeInsets.fromLTRB(
                Consonants.gutter.w,
                10.h,
                Consonants.gutter.w,
                0,
              ),
              child: Row(
                children: [
                  _circleIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: _dropRide,
                  ),
                  const Spacer(),
                  _floatingSurface(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 9.h,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.directions_car_outlined,
                            size: 15.sp,
                            color: Consonants.iconInk,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            "Active ride",
                            style: AppText.navLabel(
                              color: Consonants.iconInk,
                            ).copyWith(fontSize: 12.5.sp),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  _circleIconButton(
                    icon: Icons.shield_outlined,
                    iconColor: Consonants.danger,
                    onTap: _launchEmergency,
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

  /// Anything floating over the map is translucent canvas plus a blur —
  /// never an opaque chip.
  Widget _floatingSurface({required Widget child, bool circle = false}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Consonants.rPill.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xD6F8F9FB),
            shape: circle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: circle
                ? null
                : BorderRadius.circular(Consonants.rPill.r),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _circleIconButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: _floatingSurface(
        circle: true,
        child: SizedBox(
          width: 42.w,
          height: 42.w,
          child: Icon(
            icon,
            size: 20.sp,
            color: iconColor ?? Consonants.iconInk,
          ),
        ),
      ),
    );
  }

  Widget _statusBand() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 13.h),
      decoration: BoxDecoration(
        color: Consonants.indigoWash,
        borderRadius: BorderRadius.circular(Consonants.rPill.r),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) {
              return Container(
                width: 9.w,
                height: 9.w,
                decoration: BoxDecoration(
                  color: Consonants.violet.withValues(
                    alpha: 0.50 + 0.50 * _pulse.value,
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.navLabel(
                color: Consonants.indigo,
              ).copyWith(fontSize: 13.sp),
            ),
          ),
        ],
      ),
    );
  }

  /// The trip's focal point: who the driver is heading for, where, and what
  /// phase they're in. The screen's one gradient surface.
  Widget _focusCard() {
    return Column(
      children: [
        HeroSurface(
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52.w,
                    height: 52.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Consonants.surface.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Consonants.surface.withValues(alpha: 0.40),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      _focus.initial,
                      style: AppText.amount(
                        color: Consonants.surface,
                      ).copyWith(fontSize: 20.sp),
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _focus.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.sectionHeading(
                            color: Consonants.surface,
                          ).copyWith(fontSize: 18.sp),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          "${_focus.rating} · ${_focus.seats} ${_focus.seats == 1 ? 'seat' : 'seats'}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption(
                            color: Consonants.surface.withValues(alpha: 0.75),
                          ).copyWith(fontSize: 12.5.sp),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 10.w),
                  _phaseChip(),
                ],
              ),
              SizedBox(height: 20.h),
              Container(
                height: 1,
                color: Consonants.surface.withValues(alpha: 0.18),
              ),
              SizedBox(height: 16.h),
              Text(
                _isPickupPhase ? "PICKUP" : "DROP-OFF",
                style: AppText.navLabel(
                  color: Consonants.surface.withValues(alpha: 0.72),
                ).copyWith(fontSize: 11.5.sp, letterSpacing: 0.8),
              ),
              SizedBox(height: 6.h),
              Text(
                _focusAddress,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.paragraph(
                  color: Consonants.surface,
                ).copyWith(fontSize: 16.sp),
              ),
            ],
          ),
        ),
        SizedBox(height: Consonants.gapButtons.h),
        // Call was removed: the driver would be calling a passenger, but
        // passenger phone numbers aren't in the active-ride response, so
        // there's nothing to dial. Message + Navigate take the full row.
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: "Message",
                icon: Icons.chat_bubble_outline_rounded,
                kind: AppButtonKind.neutral,
                onPressed: _openChat,
              ),
            ),
            SizedBox(width: Consonants.gapButtons.w),
            Expanded(
              child: AppButton(
                label: "Navigate",
                icon: Icons.navigation_outlined,
                kind: AppButtonKind.secondary,
                onPressed: _openNavigation,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Phase marker on the hero — white-on-gradient, like every hero chip.
  Widget _phaseChip() {
    final (label, icon) = switch (_phase) {
      _RidePhase.headingToPickup => ("On the way", Icons.navigation_outlined),
      _RidePhase.arrivedAtPickup => ("Arrived", Icons.flag_outlined),
      _RidePhase.inTransitNextPickup => (
        "Next pickup",
        Icons.my_location_rounded,
      ),
      _RidePhase.inTransitDropoff => (
        "Dropping off",
        Icons.location_on_outlined,
      ),
      _RidePhase.lastDropoff => ("Final stop", Icons.location_on_outlined),
    };
    return HeroChip(label: label, icon: icon);
  }

  void _actionError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(CustomWidgets.customErrorSnackBar(message));
  }

  /// Guarded external launch — falls back to a SnackBar so a missing
  /// maps/dialer app never crashes the cockpit.
  Future<void> _launch(Uri uri, {required String onFail}) async {
    // Launch directly instead of gating on canLaunchUrl — the pre-check
    // needs manifest <queries> to be exhaustive and false-negatives easily;
    // launchUrl itself reports failure reliably.
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _actionError(onFail);
    } catch (_) {
      _actionError(onFail);
    }
  }

  /// Message → open the group chat for this ride (driver + passengers),
  /// reusing the same DriverChatDetail screen the messages tab opens.
  void _openChat() {
    final ride = _ride;
    if (ride == null) return;
    const palette = [
      Consonants.indigo,
      Consonants.violet,
      Consonants.indigoMid,
      Color(0xff6E4BC9),
      Color(0xff8A5BE0),
    ];
    final members = <ChatMember>[];
    for (int i = 0; i < _passengers.length; i++) {
      members.add(
        ChatMember(
          initial: _passengers[i].initial,
          color: palette[i % palette.length],
        ),
      );
    }
    final title = _passengers.isNotEmpty
        ? "${_passengers.first.name}${_passengers.length > 1 ? ' +${_passengers.length - 1}' : ''}"
        : "Ride chat";
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

  /// Navigate → open the device maps app routed to the active ride's drop
  /// coordinates. Uses the Google Maps universal directions URL, which
  /// resolves to the platform's default maps app via externalApplication.
  Future<void> _openNavigation() async {
    final ride = _ride;
    if (ride == null) return;
    // Navigate to whatever the driver is heading for NOW: the pickup while
    // fetching a rider, the drop-off once they're aboard.
    final toPickup = _isPickupPhase;
    final lat = toPickup ? ride.pickupLat : ride.dropLat;
    final lng = toPickup ? ride.pickupLng : ride.dropLng;
    if (lat == null || lng == null) {
      _actionError(
        toPickup
            ? "No pickup coordinates for this ride"
            : "No destination coordinates for this ride",
      );
      return;
    }
    // Prefer Google Maps' turn-by-turn navigation mode (starts guiding
    // immediately); fall back to the directions web URL, which Android
    // resolves into the Maps app anyway.
    final navUri = Uri.parse("google.navigation:q=$lat,$lng&mode=d");
    try {
      if (await launchUrl(navUri, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {
      // Google Maps app not installed — fall through to the web URL.
    }
    final uri = Uri.parse(
      "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng",
    );
    await _launch(uri, onFail: "Couldn't open maps");
  }

  /// Emergency / SOS → dial Pakistan's 1122 emergency line.
  Future<void> _launchEmergency() async {
    await _launch(
      Uri(scheme: 'tel', path: '1122'),
      onFail: "Couldn't open the dialer",
    );
  }

  Widget _tripStrip(LatLng pickup, LatLng drop) {
    // Total = the trip gross (what the driver collects), straight from the
    // fare model — shares are weighted now, so × riders would be wrong.
    final fareModel = _ride?.fare;
    final totalFareLabel = fareModel != null
        ? fareModel.format(fareModel.baseFare)
        : "—";
    return Consumer(
      builder: (context, ref, _) {
        // Live remaining distance/ETA from the driver's own current position
        // to the point they're headed for now (next pickup, or a drop-off).
        // Updates as they drive; "—" until routing resolves.
        final rideId = _ride?.id;
        final driverPos = rideId != null
            ? ref
                  .watch(rideTrackingProvider(RideTrackArgs(rideId, 'DRIVER')))
                  .asData
                  ?.value
                  .driver
                  ?.position
            : null;
        String distanceValue = "—";
        String durationValue = "—";
        if (driverPos != null) {
          // Live: from the driver's own position to the current target.
          final target = _isPickupPhase ? pickup : drop;
          final origin = LatLng(
            (driverPos.latitude * 1000).roundToDouble() / 1000,
            (driverPos.longitude * 1000).roundToDouble() / 1000,
          );
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
        } else if (_ride?.tripDistanceKm != null) {
          // No GPS fix yet: the FULL shared trip (all riders' stops), which
          // grows as co-passengers join.
          distanceValue = "${_ride!.tripDistanceKm!.toStringAsFixed(1)} km";
          durationValue = _ride!.tripDurationMin != null
              ? "${_ride!.tripDurationMin} min"
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

        return AppCard(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
          child: Row(
            children: [
              Expanded(
                child: _stripItem(
                  icon: Icons.straighten_rounded,
                  value: distanceValue,
                  label: "Distance",
                ),
              ),
              Container(width: 1, height: 34.h, color: Consonants.divider),
              Expanded(
                child: _stripItem(
                  icon: Icons.access_time_rounded,
                  value: durationValue,
                  label: "Duration",
                ),
              ),
              Container(width: 1, height: 34.h, color: Consonants.divider),
              Expanded(
                child: _stripItem(
                  icon: Icons.payments_outlined,
                  value: totalFareLabel,
                  label: "Trip fare",
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
  }) {
    return Column(
      children: [
        Icon(icon, size: 17.sp, color: Consonants.iconInk),
        SizedBox(height: 8.h),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.amount().copyWith(fontSize: 16.sp),
        ),
        SizedBox(height: 3.h),
        Text(label, style: AppText.caption().copyWith(fontSize: 12.sp)),
      ],
    );
  }

  Widget _remainingHeader(int count) {
    final allPicked = _passengers.every(
      (p) => p.status != PickupStatus.upcoming,
    );
    return AppSectionHeading(
      label: allPicked ? "Remaining drops" : "Next pickups",
      trailing: Text(
        "$count",
        style: AppText.caption().copyWith(fontSize: 13.sp),
      ),
    );
  }

  /// Bottom sheet with a rider's details — name, host/co-passenger, rating,
  /// the ride's route, seats, and their fare share.
  void _showPassengerDetails(Passenger p) {
    showAppSheet(
      context: context,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHeader(title: "Rider"),
            SizedBox(height: 20.h),
            Row(
              children: [
                Container(
                  width: 52.w,
                  height: 52.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.avatarColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    p.initial,
                    style: AppText.amount(
                      color: Consonants.surface,
                    ).copyWith(fontSize: 20.sp),
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.sectionHeading().copyWith(
                          fontSize: 18.sp,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        "${p.isHost ? 'Host' : 'Co-passenger'} · ${p.rating}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption().copyWith(fontSize: 12.5.sp),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            _passengerDetailRow(Icons.my_location_rounded, "Pickup", p.pickup),
            SizedBox(height: 18.h),
            _passengerDetailRow(Icons.location_on_outlined, "Drop-off", p.drop),
            SizedBox(height: 18.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _passengerDetailRow(
                    Icons.event_seat_outlined,
                    "Seats",
                    "${p.seats}",
                  ),
                ),
                Expanded(
                  child: _passengerDetailRow(
                    Icons.payments_outlined,
                    "Fare share",
                    p.fare,
                  ),
                ),
              ],
            ),
            if ((p.phone ?? '').trim().isNotEmpty) ...[
              SizedBox(height: 26.h),
              AppButton(
                label: "Call ${p.name.split(' ').first}",
                icon: Icons.call_outlined,
                onPressed: () {
                  Navigator.of(context).maybePop();
                  _callRider(p.phone!);
                },
              ),
            ],
            if (p.userId.isNotEmpty && !p.isHost) ...[
              SizedBox(height: 10.h),
              _reportBlockRow(p.userId, p.name),
            ],
          ],
        ),
      ),
    );
  }

  /// A subtle "Report · Block" row for acting on a rider.
  Widget _reportBlockRow(String userId, String name) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton.icon(
          onPressed: () {
            Navigator.of(context).maybePop();
            _reportRider(userId, name);
          },
          icon: Icon(
            Icons.flag_outlined,
            size: 16.sp,
            color: Consonants.textMuted,
          ),
          label: Text(
            "Report",
            style: AppText.navLabel().copyWith(fontSize: 13.sp),
          ),
        ),
        Text("·", style: AppText.navLabel().copyWith(fontSize: 13.sp)),
        TextButton.icon(
          onPressed: () {
            Navigator.of(context).maybePop();
            _blockRider(userId, name);
          },
          icon: Icon(
            Icons.block_rounded,
            size: 16.sp,
            color: Consonants.danger,
          ),
          label: Text(
            "Block",
            style: AppText.navLabel(
              color: Consonants.danger,
            ).copyWith(fontSize: 13.sp),
          ),
        ),
      ],
    );
  }

  Future<void> _reportRider(String userId, String name) async {
    final id = _loadedRideId;
    if (id == null) return;
    final controller = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Consonants.surface,
        title: Text(
          "Report ${name.split(' ').first}",
          style: AppText.sectionHeading().copyWith(fontSize: 18.sp),
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          cursorColor: Consonants.violet,
          style: AppText.rowLabel().copyWith(fontSize: 15.sp),
          decoration: InputDecoration(
            hintText: "What happened? (optional)",
            hintStyle: AppText.rowLabel(
              color: Consonants.textMuted,
            ).copyWith(fontSize: 15.sp),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Report"),
          ),
        ],
      ),
    );
    if (submit != true) return;
    try {
      await ref
          .read(rideServiceProvider)
          .reportUser(id, userId, reason: controller.text);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            CustomWidgets.customSuccessSnackBar("Report submitted"),
          );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            CustomWidgets.customErrorSnackBar("Couldn't submit report"),
          );
      }
    }
  }

  Future<void> _blockRider(String userId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Consonants.surface,
        title: Text(
          "Block ${name.split(' ').first}?",
          style: AppText.sectionHeading().copyWith(fontSize: 18.sp),
        ),
        content: Text(
          "You won't be matched with each other again.",
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppText.paragraph().copyWith(fontSize: 15.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Block"),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(rideServiceProvider).blockUser(userId);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(CustomWidgets.customSuccessSnackBar("User blocked"));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            CustomWidgets.customErrorSnackBar("Couldn't block user"),
          );
      }
    }
  }

  /// Dial a rider's number (only shown when one is on file). Reuses the same
  /// url_launcher path as navigation/emergency.
  Future<void> _callRider(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.trim());
    try {
      if (await launchUrl(uri)) {
        return;
      }
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          CustomWidgets.customErrorSnackBar("Couldn't start the call"),
        );
    }
  }

  Widget _passengerDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18.sp, color: Consonants.iconInk),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppText.caption().copyWith(fontSize: 12.5.sp)),
              SizedBox(height: 3.h),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.rowLabel().copyWith(fontSize: 15.sp),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _remainingTile(_RemainingItem item) {
    return AppListRow(
      icon: item.asPickup
          ? Icons.my_location_rounded
          : Icons.location_on_outlined,
      iconBg: Consonants.indigoWash,
      title: item.passenger.name,
      meta: item.asPickup ? item.passenger.pickup : item.passenger.drop,
      onTap: () => _showPassengerDetails(item.passenger),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 20.sp,
        color: Consonants.textMuted,
      ),
    );
  }

  Widget _stickyCta(double bottomInset) {
    // The floating nav sits over this panel, so the CTA reserves the nav's
    // clearance underneath itself rather than hiding behind it.
    return Container(
      padding: EdgeInsets.fromLTRB(
        Consonants.gutter.w,
        12.h,
        Consonants.gutter.w,
        Consonants.navClearance.h + bottomInset * 0.2,
      ),
      decoration: const BoxDecoration(
        color: Consonants.canvas,
        border: Border(top: BorderSide(color: Consonants.divider)),
      ),
      child: AppButton(
        label: _ctaLabel,
        icon: _phase == _RidePhase.lastDropoff
            ? Icons.check_circle_outline_rounded
            : Icons.arrow_forward_rounded,
        isLoading: _advancing || _completing,
        onPressed: (_advancing || _completing) ? null : _advance,
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
      color: Consonants.indigoWash,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 34.sp, color: Consonants.iconInk),
          SizedBox(height: 10.h),
          Text(
            "Loading map…",
            style: AppText.caption().copyWith(fontSize: 13.sp),
          ),
        ],
      ),
    );
  }

  // ─── Loading state ──────────────────────────────────────

  Widget _loadingState() {
    return const SafeArea(
      child: Center(
        child: CircularProgressIndicator(
          color: Consonants.indigo,
          strokeWidth: 2.5,
        ),
      ),
    );
  }

  // ─── Empty state ────────────────────────────────────────

  Widget _emptyState({String? message}) {
    return SafeArea(
      // Explicit full width — the tab sits inside a Stack, which passes loose
      // constraints, so a stretched column would size to its widest child and
      // hug the left gutter instead of filling the screen.
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
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
                    color: Consonants.iconInk,
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                "No active ride right now",
                textAlign: TextAlign.center,
                style: AppText.screenTitle().copyWith(fontSize: 24.sp),
              ),
              if (message != null) ...[
                SizedBox(height: 10.h),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppText.paragraph().copyWith(fontSize: 15.5.sp),
                ),
              ],
              SizedBox(height: 32.h),
              AppButton(
                label: "Go to Rides",
                icon: Icons.directions_car_outlined,
                onPressed: () =>
                    ref.read(bottomNavIndexProvider.notifier).select(1),
              ),
            ],
          ),
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

/// Post-trip cash-collection sheet: each rider's fare with a tap-to-collect
/// action. The driver marks cash received per rider; each tap hits the backend
/// so the ledger reflects what was actually collected.
class _CollectCashSheet extends ConsumerStatefulWidget {
  final String rideId;
  final List<RidePaymentEntry> initial;
  const _CollectCashSheet({required this.rideId, required this.initial});

  @override
  ConsumerState<_CollectCashSheet> createState() => _CollectCashSheetState();
}

class _CollectCashSheetState extends ConsumerState<_CollectCashSheet> {
  late final List<RidePaymentEntry> _payments = List.of(widget.initial);
  final Set<String> _busy = {};

  Future<void> _collect(RidePaymentEntry p) async {
    if (_busy.contains(p.userId) || p.isCollected) return;
    setState(() => _busy.add(p.userId));
    try {
      final updated = await ref
          .read(rideServiceProvider)
          .collectPayment(widget.rideId, p.userId);
      if (!mounted) return;
      setState(() {
        final i = _payments.indexWhere((e) => e.userId == p.userId);
        if (i != -1) _payments[i] = updated;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            CustomWidgets.customErrorSnackBar("Couldn't mark collected"),
          );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(p.userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _payments.fold<double>(0, (s, p) => s + p.amount);
    final collected = _payments
        .where((p) => p.isCollected)
        .fold<double>(0, (s, p) => s + p.amount);
    final currency = _payments.isNotEmpty ? _payments.first.currency : 'PKR';
    final symbol = currency == 'PKR'
        ? 'Rs'
        : currency == 'USD'
        ? '\$'
        : currency;

    return Container(
      padding: EdgeInsets.fromLTRB(
        Consonants.gutter.w,
        16.h,
        Consonants.gutter.w,
        24.h + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Consonants.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Consonants.rSheet.r),
        ),
        boxShadow: Consonants.sheetLift,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHeader(title: "Collect cash"),
          SizedBox(height: 18.h),
          // The money is the headline: what's in hand out of what's owed.
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                symbol,
                style: AppText.amount(
                  color: Consonants.textMuted,
                ).copyWith(fontSize: 16.sp),
              ),
              SizedBox(width: 8.w),
              Text(
                "${collected.round()}",
                style: AppText.figure(
                  color: Consonants.credit,
                ).copyWith(fontSize: 34.sp),
              ),
              SizedBox(width: 8.w),
              Text(
                "of ${total.round()}",
                style: AppText.caption().copyWith(fontSize: 13.sp),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          for (int i = 0; i < _payments.length; i++) ...[
            _row(_payments[i]),
            if (i != _payments.length - 1) const AppDivider(),
          ],
          SizedBox(height: 24.h),
          AppButton(
            label: "Done",
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }

  Widget _row(RidePaymentEntry p) {
    final name = (p.name == null || p.name!.trim().isEmpty)
        ? (p.isHost ? "Host" : "Passenger")
        : p.name!.trim();
    final busy = _busy.contains(p.userId);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Consonants.rowVertical.h),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name + (p.isHost ? " · Host" : ""),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.rowLabel().copyWith(fontSize: 16.sp),
                ),
                SizedBox(height: 4.h),
                Text(
                  "${p.amountLabel} · cash",
                  style: AppText.caption().copyWith(fontSize: 12.5.sp),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          if (p.isCollected)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 19.sp,
                  color: Consonants.credit,
                ),
                SizedBox(width: 6.w),
                Text(
                  "Collected",
                  style: AppText.navLabel(
                    color: Consonants.credit,
                  ).copyWith(fontSize: 13.sp),
                ),
              ],
            )
          else
            GestureDetector(
              onTap: busy ? null : () => _collect(p),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                decoration: BoxDecoration(
                  gradient: Consonants.actionGradient,
                  borderRadius: BorderRadius.circular(Consonants.rPill.r),
                ),
                child: busy
                    ? SizedBox(
                        width: 15.sp,
                        height: 15.sp,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Consonants.surface,
                          ),
                        ),
                      )
                    : Text(
                        "Mark paid",
                        style: AppText.navLabel(
                          color: Consonants.surface,
                        ).copyWith(fontSize: 13.sp),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
