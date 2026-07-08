import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/availableRidesProvider.dart';
import 'package:ride_sharing/provider/mapProvider.dart';
import 'package:ride_sharing/provider/myRidesProvider.dart';
import 'package:ride_sharing/provider/providers.dart';
import 'package:ride_sharing/provider/rideRequestProvider.dart';
import 'package:ride_sharing/view/nearbyRidesMap.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';
import 'package:ride_sharing/widgets/custom/floatingRequestBanner.dart';
import 'package:ride_sharing/widgets/maps/placeSearchField.dart';

class Ridescreen extends ConsumerStatefulWidget {
  const Ridescreen({super.key});

  @override
  ConsumerState<Ridescreen> createState() => _RidescreenState();
}

/// Hard radius cap for the available-rides search. Anything farther
/// than this from the user's typed pickup is hidden, regardless of
/// what the backend returns.
const double _kRadiusKm = 5.0;

enum _RideSort { best, nearest, cheapest, soonest, topRated }

extension _RideSortLabel on _RideSort {
  String get label => switch (this) {
        _RideSort.best => 'Best match',
        _RideSort.nearest => 'Nearest',
        _RideSort.cheapest => 'Cheapest',
        _RideSort.soonest => 'Soonest',
        _RideSort.topRated => 'Top rated',
      };
}

class _RidescreenState extends ConsumerState<Ridescreen> {
  late final TextEditingController _pickupController;
  late final TextEditingController _dropController;

  /// Rides the user dismissed ("not interested") this session — filtered out
  /// so they don't keep reappearing on refresh.
  final Set<String> _dismissed = {};

  /// How the results list is ordered. "Best match" keeps the backend's
  /// route-overlap ranking; the rest sort client-side.
  _RideSort _sort = _RideSort.best;

  List<AvailableRide> _sortRides(List<AvailableRide> rides) {
    final list = [...rides];
    switch (_sort) {
      case _RideSort.best:
        break; // keep backend order (route-overlap / nearest-first)
      case _RideSort.nearest:
        list.sort((a, b) =>
            (a.distanceKm ?? 1e9).compareTo(b.distanceKm ?? 1e9));
      case _RideSort.cheapest:
        list.sort((a, b) =>
            (a.fareForRider ?? 1e9).compareTo(b.fareForRider ?? 1e9));
      case _RideSort.soonest:
        list.sort((a, b) {
          // Scheduled rides ordered by departure; on-demand ("now") first.
          final at = a.departureTime?.millisecondsSinceEpoch ?? 0;
          final bt = b.departureTime?.millisecondsSinceEpoch ?? 0;
          return at.compareTo(bt);
        });
      case _RideSort.topRated:
        list.sort((a, b) =>
            (b.hostRating ?? 0).compareTo(a.hostRating ?? 0));
    }
    return list;
  }

  /// Keeps rides with enough seats for the party and drops any the user
  /// dismissed. The backend (PostGIS) already bounded the list to within
  /// [_kRadiusKm] of the pickup and returned it nearest-first.
  List<AvailableRide> _filterBySeats(
    List<AvailableRide> rides,
    int neededSeats,
  ) {
    return rides
        .where((r) => r.seatsAvailable >= neededSeats)
        .where((r) => !_dismissed.contains(r.id))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    // Hydrate the form from any previously-saved request so the
    // user doesn't lose their input when they navigate away and back.
    final saved = ref.read(rideRequestProvider);
    _pickupController = TextEditingController(text: saved.pickup);
    _dropController = TextEditingController(text: saved.drop);
    // Default the pickup to the user's current location (still editable).
    if (saved.pickup.isEmpty) {
      _prefillPickupFromCurrentLocation();
    }
  }

  /// Fetches the user's GPS location, reverse-geocodes it to an address, and
  /// fills the pickup field with it — unless they've already typed/saved one.
  /// Fire-and-forget from initState; silently no-ops on permission/GPS errors.
  Future<void> _prefillPickupFromCurrentLocation() async {
    if (ref.read(rideRequestProvider).pickup.isNotEmpty) return;
    try {
      final here = await ref.read(currentLocationProvider.future);
      // Bail if the user typed a pickup while we were resolving.
      if (!mounted || ref.read(rideRequestProvider).pickup.isNotEmpty) return;
      final details =
          await ref.read(geocodingServiceProvider).reverseGeocode(here);
      if (!mounted || ref.read(rideRequestProvider).pickup.isNotEmpty) return;
      final address = (details?.displayLine ?? '').trim();
      final label = address.isNotEmpty
          ? address
          : '${here.latitude.toStringAsFixed(5)}, '
              '${here.longitude.toStringAsFixed(5)}';
      ref.read(rideRequestProvider.notifier).setPickup(label, latLng: here);
      _pickupController.text = label;
    } catch (_) {
      // No location / permission denied / geocode failed — leave it for the
      // user to fill in manually.
    }
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropController.dispose();
    super.dispose();
  }

  /// Save tap: commits the search criteria and triggers the rides
  /// refetch. Requires the user to have *picked* their pickup &
  /// destination from the autocomplete dropdown — free-typed text
  /// without coords can't drive a radius search.
  ///
  /// Coords are pulled from [rideRequestProvider] (set by the
  /// [PlaceSearchField]s `onPicked` callbacks); previous bug was that
  /// this method called `save()` without forwarding the LatLngs and
  /// silently nuked them.
  void _onSaveTap() {
    final state = ref.read(rideRequestProvider);
    final pickup = _pickupController.text.trim();
    final drop = _dropController.text.trim();

    if (pickup.isEmpty || drop.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        CustomWidgets.customErrorSnackBar(
          "Please enter pickup and destination",
        ),
      );
      return;
    }
    if (state.pickupLatLng == null || state.dropLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        CustomWidgets.customErrorSnackBar(
          "Please pick pickup & destination from the suggestions",
        ),
      );
      return;
    }

    ref.read(rideRequestProvider.notifier).save(
          pickup: pickup,
          drop: drop,
          seats: state.seats,
          pickupLatLng: state.pickupLatLng,
          dropLatLng: state.dropLatLng,
        );

    // Trigger the rides refetch. The provider reads pickup lat/lng
    // from rideRequestProvider, so this picks up the new criteria.
    ref.invalidate(availableRidesProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      CustomWidgets.customSuccessSnackBar(
        "Showing rides within ${_kRadiusKm.round()} km",
      ),
    );
  }

  /// View-Request tap on a real ride card. Routes the user to the
  /// viewRequest screen pre-filled with THAT ride's coords/labels so
  /// the next screen can show route, ETA, etc. Seats default to the
  /// user's selected seats (from the search form), capped at what
  /// the ride actually has available.
  ///
  /// We deliberately DON'T overwrite [rideRequestProvider] here —
  /// the searcher's own pickup/destination/seats are their search
  /// criteria, and viewRequest uses them to render the searcher-side
  /// "Your Route" section (so they can compare their intent against
  /// the ride they're joining).
  void _onJoinRide(AvailableRide ride) {
    final desiredSeats = ref.read(rideRequestProvider).seats;
    final seats = desiredSeats > ride.seatsAvailable
        ? ride.seatsAvailable
        : desiredSeats;

    final pickupLatLng = LatLng(ride.pickupLat, ride.pickupLng);
    final dropLatLng = LatLng(ride.dropLat, ride.dropLng);

    // push (not go) so the back arrow on viewRequest can pop back here.
    context.push(
      Approutes.viewRequest,
      extra: <String, dynamic>{
        'rideId': ride.id,
        'pickup': ride.pickup,
        'drop': ride.drop,
        'seats': seats,
        'pickupLatLng': pickupLatLng,
        'dropLatLng': dropLatLng,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(availableRidesProvider);
    final rides = async.value ?? const <AvailableRide>[];
    // True the moment the user has actually committed pickup/drop via
    // Save — until then we show a prompt instead of a (necessarily
    // empty) results list.
    // A real search needs BOTH a pickup and a destination. Gating on pickup
    // alone made the GPS auto-prefill flip this true and flash "No rides
    // within 5 km" before the user has even entered a destination.
    final hasSearch = ref.watch(
          rideRequestProvider.select(
              (s) => s.pickupLatLng != null && s.dropLatLng != null),
        );
    final neededSeats =
        ref.watch(rideRequestProvider.select((s) => s.seats));
    final filtered = _filterBySeats(rides, neededSeats);

    // Whether the passenger is already in a ride drives the whole screen,
    // so we watch myRides unconditionally and use it to pick the view.
    final myRidesAsync = ref.watch(myRidesProvider);
    final myRides = myRidesAsync.value ?? const <AvailableRide>[];
    // "Committed" = hosting OR having joined an active (PENDING/ACCEPTED)
    // ride. Committed → manage "Your Rides"; otherwise → "Find Rides".
    // The instant they leave/cancel/complete, this flips and Find returns.
    final committed = myRides.isNotEmpty;

    return Stack(
      children: [
        SafeArea(
          child: RefreshIndicator(
        color: Consonants.primaryColor,
        onRefresh: () async {
          // Refresh both: myRides decides which view shows, availableRides
          // is the find list. Await myRides so the spinner reflects the
          // commitment check that picks the view.
          ref.invalidate(myRidesProvider);
          ref.invalidate(availableRidesProvider);
          await ref.read(myRidesProvider.future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.only(bottom: 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ScreenHeader(
                hasSearch: hasSearch,
                matchCount: committed ? myRides.length : filtered.length,
                isMyRidesTab: committed,
              ),
              SizedBox(height: 14.h),
              // No manual tab toggle: the view is decided by whether the
              // passenger is already in a ride. Committed (host OR
              // co-passenger) → "Your Rides" only; otherwise → "Find Rides".
              // While we don't yet know (first load), show a spinner so the
              // screen doesn't flash Find Rides before snapping to Your Rides.
              if (myRidesAsync.isLoading && myRides.isEmpty)
                const _LoadingState()
              else if (committed)
                _buildMyRidesBody(myRidesAsync, myRides)
              else ...[
                _searchForm(),
                if (hasSearch) ...[
                  SizedBox(height: 12.h),
                  _radiusCaption(),
                ],
                SizedBox(height: 14.h),
                _buildBody(async, rides, filtered, hasSearch),
              ],
              SizedBox(height: 14.h),
            ],
          ),
        ),
          ),
        ),
        // Floating, real-time request card over the ride page (inDrive style):
        // incoming join requests / driver offers with Accept/Decline inline.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: const FloatingRequestBanner(),
            ),
          ),
        ),
      ],
    );
  }

  /// "Your Rides" body — loading on first fetch, error card on
  /// failure, friendly empty state when the host hasn't created any
  /// active rides, otherwise the list rendered as [_MyRideCard]s.
  Widget _buildMyRidesBody(
    AsyncValue<List<AvailableRide>> async,
    List<AvailableRide> rides,
  ) {
    if (async.isLoading && rides.isEmpty) return const _LoadingState();
    if (async.hasError && rides.isEmpty) {
      return _ErrorState(
        message: ErrorHandler.message(async.error),
        onRetry: () => ref.invalidate(myRidesProvider),
      );
    }
    if (rides.isEmpty) return const _NoMyRidesState();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < rides.length; i++) ...[
          _FeaturedRideCard(
            ride: rides[i],
            isMyRide: true,
            onViewRequest: () => _onViewMyRide(rides[i]),
            onDecline: () => _onDeclineMyRide(rides[i]),
          ),
          if (i != rides.length - 1) SizedBox(height: 14.h),
        ],
      ],
    );
  }

  /// Decline-tap on a "Your Rides" card. Rides you host are cancelled;
  /// rides you joined as a co-passenger are left.
  Future<void> _onDeclineMyRide(AvailableRide ride) async {
    if (ride.youAreHost) {
      await _onCancelMyRide(ride);
    } else {
      await _onLeaveMyRide(ride);
    }
  }

  /// Leave a ride you joined as a co-passenger. Frees your slot and clears
  /// your "one ride at a time" commitment, so you can find/join/create again.
  Future<void> _onLeaveMyRide(AvailableRide ride) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: CustomWidgets.customText(
          "Leave this ride?",
          15.sp,
          Consonants.boldTextColor,
          FontWeight.w800,
        ),
        content: CustomWidgets.customText(
          "You'll be removed from this trip and can find another ride afterward.",
          12.sp,
          Consonants.greyColor,
          FontWeight.w500,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: CustomWidgets.customText(
              "Keep",
              12.sp,
              Consonants.boldTextColor,
              FontWeight.w700,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: CustomWidgets.customText(
              "Leave ride",
              12.sp,
              const Color(0xffEF4444),
              FontWeight.w800,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(rideServiceProvider).leaveRide(ride.id);
      if (!mounted) return;
      ref.invalidate(myRidesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        CustomWidgets.customSuccessSnackBar("You left the ride"),
      );
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.show(context, e);
    }
  }

  /// Cancel-tap on a "Your Rides" card. Pops a confirmation dialog
  /// (irreversible action) then hits `cancelRide` on the backend. On
  /// success, invalidates [myRidesProvider] so the card disappears
  /// from the list. The new-ride guard on the homepage Book button
  /// also reads this provider, so a fresh cancel unblocks creation.
  Future<void> _onCancelMyRide(AvailableRide ride) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: CustomWidgets.customText(
          "Cancel this ride?",
          15.sp,
          Consonants.boldTextColor,
          FontWeight.w800,
        ),
        content: CustomWidgets.customText(
          "Any passengers who've joined will be notified. You can publish a new ride afterward.",
          12.sp,
          Consonants.greyColor,
          FontWeight.w500,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: CustomWidgets.customText(
              "Keep",
              12.sp,
              Consonants.boldTextColor,
              FontWeight.w700,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: CustomWidgets.customText(
              "Cancel ride",
              12.sp,
              const Color(0xffEF4444),
              FontWeight.w800,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    try {
      await ref.read(rideServiceProvider).cancelRide(ride.id);
      if (!mounted) return;
      ref.invalidate(myRidesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        CustomWidgets.customSuccessSnackBar("Ride cancelled"),
      );
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.show(context, e);
    }
  }

  /// Tap on a "Your Rides" card — just navigates to viewRequest with
  /// the ride id; the host-vs-searcher detection on that screen takes
  /// care of swapping labels/copy for the host view.
  void _onViewMyRide(AvailableRide ride) {
    final pickupLatLng = LatLng(ride.pickupLat, ride.pickupLng);
    final dropLatLng = LatLng(ride.dropLat, ride.dropLng);
    context.push(
      Approutes.viewRequest,
      extra: <String, dynamic>{
        'rideId': ride.id,
        'pickup': ride.pickup,
        'drop': ride.drop,
        'seats': ride.seatsAvailable,
        'pickupLatLng': pickupLatLng,
        'dropLatLng': dropLatLng,
      },
    );
  }

  /// Subtle "Within 5 km of your pickup" caption shown under the
  /// search form once the user has saved a search. Anchors the radius
  /// rule visually so an empty result set doesn't feel like a bug.
  Widget _radiusCaption() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 22.w),
      child: Row(
        children: [
          Icon(
            Icons.adjust_rounded,
            size: 12.sp,
            color: Consonants.primaryColor,
          ),
          SizedBox(width: 6.w),
          CustomWidgets.customText(
            "Within ${_kRadiusKm.round()} km of your pickup",
            10.sp,
            Consonants.greyColor,
            FontWeight.w600,
          ),
        ],
      ),
    );
  }

  /// State-aware "what to show under the search form" — prompt when
  /// no search has been saved, loading on first fetch, error card on
  /// failure, friendly empty state when nothing matches within the
  /// radius, otherwise the actual ride list. During a *refresh* (we
  /// have stale data already) we keep showing the list and let the
  /// RefreshIndicator spinner cover the loading signal.
  Widget _buildBody(
    AsyncValue<List<AvailableRide>> async,
    List<AvailableRide> rides,
    List<AvailableRide> filtered,
    bool hasSearch,
  ) {
    if (!hasSearch) return const _SearchPrompt();
    if (async.isLoading && rides.isEmpty) return const _LoadingState();
    if (async.hasError && rides.isEmpty) {
      return _ErrorState(
        message: ErrorHandler.message(async.error),
        onRetry: () => ref.invalidate(availableRidesProvider),
      );
    }
    if (filtered.isEmpty) return const _NoNearbyState();

    final sorted = _sortRides(filtered);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _sortBar()),
            SizedBox(width: 8.w),
            _mapButton(sorted),
            SizedBox(width: 20.w),
          ],
        ),
        SizedBox(height: 12.h),
        for (int i = 0; i < sorted.length; i++) ...[
          _FeaturedRideCard(
            ride: sorted[i],
            onViewRequest: () => _onJoinRide(sorted[i]),
            onDecline: () {
              setState(() => _dismissed.add(sorted[i].id));
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  CustomWidgets.customErrorSnackBar("Ride dismissed"),
                );
            },
          ),
          if (i != sorted.length - 1) SizedBox(height: 14.h),
        ],
      ],
    );
  }

  /// Opens the nearby-rides map; tapping a pin joins that ride.
  Widget _mapButton(List<AvailableRide> rides) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => NearbyRidesMapScreen(
          rides: rides,
          title: 'Nearby rides',
          onTapRide: _onJoinRide,
        ),
      )),
      child: Container(
        height: 34.h,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Consonants.primaryColor,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_rounded, size: 14.sp, color: Consonants.whiteColor),
            SizedBox(width: 5.w),
            CustomWidgets.customText(
                'Map', 11.sp, Consonants.whiteColor, FontWeight.w700),
          ],
        ),
      ),
    );
  }

  /// Horizontal chip row to reorder the results.
  Widget _sortBar() {
    return SizedBox(
      height: 34.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        itemCount: _RideSort.values.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (_, i) {
          final s = _RideSort.values[i];
          final selected = s == _sort;
          return GestureDetector(
            onTap: () => setState(() => _sort = s),
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              decoration: BoxDecoration(
                color: selected
                    ? Consonants.primaryColor
                    : Consonants.whiteColor,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: selected
                      ? Consonants.primaryColor
                      : Consonants.lightGreyColor,
                ),
              ),
              child: CustomWidgets.customText(
                s.label,
                11.sp,
                selected ? Consonants.whiteColor : Consonants.greyColor,
                FontWeight.w700,
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────── SEARCH FORM ───────────────────────
  Widget _searchForm() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.circular(20.r),
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
          // ─── Pickup field ───
          Row(
            children: [
              Container(
                width: 14.w,
                height: 14.w,
                decoration: BoxDecoration(
                  color: Consonants.whiteColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Consonants.primaryColor,
                    width: 3,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _placesField(
                  controller: _pickupController,
                  hint: "Pickup location",
                  onPicked: (description, latLng) {
                    ref.read(rideRequestProvider.notifier).setPickup(
                          description,
                          latLng: latLng,
                        );
                  },
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Container(
              height: 1,
              color: Consonants.lightGreyColor,
            ),
          ),
          // ─── Destination field ───
          Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                size: 18.sp,
                color: const Color(0xffEF4444),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _placesField(
                  controller: _dropController,
                  hint: "Where are you going?",
                  onPicked: (description, latLng) {
                    ref.read(rideRequestProvider.notifier).setDrop(
                          description,
                          latLng: latLng,
                        );
                  },
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Container(
              height: 1,
              color: Consonants.lightGreyColor,
            ),
          ),
          // ─── Seats counter ───
          Row(
            children: [
              Icon(
                Icons.event_seat_rounded,
                size: 16.sp,
                color: Consonants.primaryColor,
              ),
              SizedBox(width: 10.w),
              CustomWidgets.customText(
                "Seats needed",
                12.sp,
                Consonants.boldTextColor,
                FontWeight.w600,
              ),
              const Spacer(),
              _seatStepper(),
            ],
          ),
          SizedBox(height: 14.h),
          // ─── Save button ───
          GestureDetector(
            onTap: _onSaveTap,
            child: Container(
              width: double.infinity,
              height: 46.h,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14.r),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Consonants.primaryColor,
                    Color(0xff5AC8FA),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        Consonants.primaryColor.withValues(alpha: 0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_added_rounded,
                    size: 16.sp,
                    color: Consonants.whiteColor,
                  ),
                  SizedBox(width: 6.w),
                  CustomWidgets.customText(
                    "Save",
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
    );
  }

  /// Geoapify-backed places autocomplete. As the user types, suggestions
  /// appear in a floating dropdown; tapping one hydrates the controller
  /// and fires [onPicked] with the formatted address + resolved coords.
  /// Replaces the previous `GooglePlaceAutoCompleteTextField` wrapper.
  Widget _placesField({
    required TextEditingController controller,
    required String hint,
    required void Function(String description, LatLng latLng) onPicked,
  }) {
    return PlaceSearchField(
      controller: controller,
      hint: hint,
      inputDecoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 12.sp,
          color: Consonants.greyColor,
          fontWeight: FontWeight.w500,
          fontFamily: Consonants.fontFamily,
        ),
        border: InputBorder.none,
        isCollapsed: true,
        contentPadding: EdgeInsets.symmetric(vertical: 4.h),
      ),
      textStyle: TextStyle(
        fontSize: 12.sp,
        color: Consonants.boldTextColor,
        fontWeight: FontWeight.w700,
        fontFamily: Consonants.fontFamily,
      ),
      onPicked: (s) => onPicked(s.formatted, s.coords),
    );
  }

  Widget _seatStepper() {
    final seats = ref.watch(rideRequestProvider.select((s) => s.seats));
    final notifier = ref.read(rideRequestProvider.notifier);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Consonants.lightBlueColor,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seatButton(
            Icons.remove_rounded,
            enabled: seats > 1,
            onTap: () => notifier.setSeats(seats - 1),
          ),
          SizedBox(width: 12.w),
          SizedBox(
            width: 14.w,
            child: Center(
              child: CustomWidgets.customText(
                "$seats",
                13.sp,
                Consonants.boldTextColor,
                FontWeight.w800,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          _seatButton(
            Icons.add_rounded,
            enabled: seats < 4,
            onTap: () => notifier.setSeats(seats + 1),
          ),
        ],
      ),
    );
  }

  Widget _seatButton(
    IconData icon, {
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 24.w,
        height: 24.w,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled
              ? Consonants.primaryColor
              : Consonants.lightGreyColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 14.sp,
          color: enabled ? Consonants.whiteColor : Consonants.greyColor,
        ),
      ),
    );
  }
}

/// ───────────────────────── HEADER ─────────────────────────
class _ScreenHeader extends StatelessWidget {
  final bool hasSearch;
  final int matchCount;
  final bool isMyRidesTab;

  const _ScreenHeader({
    required this.hasSearch,
    required this.matchCount,
    required this.isMyRidesTab,
  });

  @override
  Widget build(BuildContext context) {
    // Subtitle is context-aware on three axes:
    //   1. which tab is active (find rides vs your rides)
    //   2. for find rides: whether the user has saved a search
    //   3. for either: zero / one / many results
    final subtitle = isMyRidesTab
        ? (matchCount == 0
            ? "You're not in a ride right now"
            : "Your active ride — manage it below")
        : (!hasSearch
            ? "Set pickup & destination to find nearby rides"
            : matchCount == 0
                ? "No nearby rides match your search"
                : matchCount == 1
                    ? "1 nearby ride matches your search"
                    : "$matchCount nearby rides match your search");
    final title = isMyRidesTab ? "Your Rides" : "Available Rides";

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomWidgets.customText(
            title,
            18.sp,
            Consonants.boldTextColor,
            FontWeight.w700,
          ),
          SizedBox(height: 2.h),
          CustomWidgets.customText(
            subtitle,
            11.sp,
            Consonants.greyColor,
            FontWeight.w500,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

// ─────────────────── PROMPT / LOADING / ERROR / EMPTY STATES ───────

/// Shown on the very first fetch — once stale data exists in the
/// Riverpod cache we keep rendering it and let RefreshIndicator's
/// spinner cover the loading signal instead. Same card chrome as
/// [_EmptyState] so the screen height stays consistent across states.
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 20.w),
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Consonants.lightGreyColor, width: 1.2),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 28.w,
            height: 28.w,
            child: const CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Consonants.primaryColor,
            ),
          ),
          SizedBox(height: 14.h),
          CustomWidgets.customText(
            "Finding rides near you…",
            13.sp,
            Consonants.boldTextColor,
            FontWeight.w700,
          ),
          SizedBox(height: 4.h),
          CustomWidgets.customText(
            "Just a moment",
            11.sp,
            Consonants.greyColor,
            FontWeight.w500,
          ),
        ],
      ),
    );
  }
}

/// Shown when the backend fetch fails AND we don't have any cached
/// rides to show instead. Friendly message + retry button.
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.symmetric(vertical: 32.h, horizontal: 20.w),
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Consonants.lightGreyColor, width: 1.2),
      ),
      child: Column(
        children: [
          Container(
            width: 64.w,
            height: 64.w,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xffFEE2E2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cloud_off_rounded,
              size: 28.sp,
              color: const Color(0xffEF4444),
            ),
          ),
          SizedBox(height: 12.h),
          CustomWidgets.customText(
            "Couldn't load rides",
            13.sp,
            Consonants.boldTextColor,
            FontWeight.w700,
          ),
          SizedBox(height: 4.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            child: CustomWidgets.customText(
              message,
              11.sp,
              Consonants.greyColor,
              FontWeight.w500,
              textAlign: TextAlign.center,
              maxLines: 3,
            ),
          ),
          SizedBox(height: 16.h),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
                ),
                borderRadius: BorderRadius.circular(40.r),
                boxShadow: [
                  BoxShadow(
                    color: Consonants.primaryColor.withValues(alpha: 0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded,
                      size: 13.sp, color: Consonants.whiteColor),
                  SizedBox(width: 6.w),
                  CustomWidgets.customText(
                    "Try again",
                    11.sp,
                    Consonants.whiteColor,
                    FontWeight.w700,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── PROMPT / NO-NEARBY STATES ────────────

/// Shown before the user has saved any search criteria. Replaces the
/// previous "All rides" default — the screen used to show every
/// available ride from anywhere, which scaled poorly and ignored the
/// user's actual location intent.
class _SearchPrompt extends StatelessWidget {
  const _SearchPrompt();

  @override
  Widget build(BuildContext context) {
    return _emptyStateShell(
      icon: Icons.travel_explore_rounded,
      title: "Tell us where you're going",
      subtitle:
          "Pick your pickup and destination above, then tap Save to see rides within ${_kRadiusKm.round()} km.",
    );
  }
}

/// Shown when a search HAS been saved but the backend returned nothing
/// (or nothing made it through the radius + seats filter). Different
/// copy from [_SearchPrompt] so the user knows the search actually ran.
class _NoNearbyState extends StatelessWidget {
  const _NoNearbyState();

  @override
  Widget build(BuildContext context) {
    return _emptyStateShell(
      icon: Icons.location_off_rounded,
      title:
          "No rides within ${_kRadiusKm.round()} km of your pickup",
      subtitle:
          "Try a different pickup, or pull down to refresh in a moment.",
    );
  }
}

/// Shown on the "Your Rides" tab when the host hasn't created any
/// active rides yet. Points them at the homepage's Book flow which
/// is where new rides get created.
class _NoMyRidesState extends StatelessWidget {
  const _NoMyRidesState();

  @override
  Widget build(BuildContext context) {
    return _emptyStateShell(
      icon: Icons.workspace_premium_rounded,
      title: "You haven't created any rides yet",
      subtitle:
          "Head back to the home tab and tap Book to publish a ride others can join.",
    );
  }
}

/// Shared chrome for empty-style states. Same card shape across
/// prompt / no-nearby / loading / error so the screen height doesn't
/// jump when transitioning between them.
Widget _emptyStateShell({
  required IconData icon,
  required String title,
  required String subtitle,
  Widget? action,
}) {
  return Container(
    margin: EdgeInsets.symmetric(horizontal: 20.w),
    padding: EdgeInsets.symmetric(vertical: 32.h, horizontal: 20.w),
    decoration: BoxDecoration(
      color: Consonants.whiteColor,
      borderRadius: BorderRadius.circular(20.r),
      border: Border.all(color: Consonants.lightGreyColor, width: 1.2),
    ),
    child: Column(
      children: [
        Container(
          width: 64.w,
          height: 64.w,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Consonants.lightBlueColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 28.sp, color: Consonants.primaryColor),
        ),
        SizedBox(height: 12.h),
        CustomWidgets.customText(
          title,
          13.sp,
          Consonants.boldTextColor,
          FontWeight.w700,
          textAlign: TextAlign.center,
          maxLines: 2,
        ),
        SizedBox(height: 4.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          child: CustomWidgets.customText(
            subtitle,
            11.sp,
            Consonants.greyColor,
            FontWeight.w500,
            textAlign: TextAlign.center,
            maxLines: 3,
          ),
        ),
        if (action != null) ...[
          SizedBox(height: 16.h),
          action,
        ],
      ],
    ),
  );
}

/// ─────────────────── FEATURED RIDE CARD ───────────────────
/// Mirrors the driver-side ride summary card (`driverRides.dart`):
/// gradient host strip → 3 stat tiles → route timeline → distance /
/// duration strip → Decline + View Request buttons.
///
/// Difference from the driver version: the middle stat tile shows the
/// *current passenger's* fare ("Your fare") rather than the trip's
/// total fare, since the driver sees aggregate while the passenger
/// sees only what they'll personally pay.
class _FeaturedRideCard extends StatelessWidget {
  final AvailableRide ride;
  final VoidCallback onViewRequest;
  final VoidCallback onDecline;

  /// True when this card belongs to the authenticated host themselves
  /// (rendered on the "Your Rides" tab). Only changes the action-button
  /// labels: "Decline" / "View Request" → "Cancel" / "Manage Ride".
  /// The rest of the card chrome stays identical so the two tabs feel
  /// visually unified.
  final bool isMyRide;

  const _FeaturedRideCard({
    required this.ride,
    required this.onViewRequest,
    required this.onDecline,
    this.isMyRide = false,
  });

  // ── Display adapters. Pulled out as getters so the helper widgets
  //    (`_hostStrip`, `_statsPills`, `_routeTimeline`) keep their
  //    short, readable names — the underlying source is the immutable
  //    [AvailableRide] passed in.
  String get name => ride.hostName;
  String get rating => ride.hostRating?.toStringAsFixed(1) ?? '—';
  String get trips => ride.hostTrips.toString();
  int get minutes => ride.etaMinutes ?? 0;
  String get distance => ride.distanceKm?.toStringAsFixed(1) ?? '—';
  String get yourFare =>
      ride.fareForRider != null ? 'Rs ${ride.fareForRider!.round()}' : '—';
  String get avgRating => ride.hostRating?.toStringAsFixed(1) ?? '—';
  String get pickup => ride.pickup;
  String get drop => ride.drop;
  int get riders => ride.ridersJoined;
  LatLng? get pickupLatLng => LatLng(ride.pickupLat, ride.pickupLng);
  LatLng? get dropLatLng => LatLng(ride.dropLat, ride.dropLng);
  String? get hostGender => ride.hostGender;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String get _scheduledLabel {
    final dt = ride.departureTime!;
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ap = dt.hour < 12 ? 'AM' : 'PM';
    return '${_months[dt.month - 1]} ${dt.day}, $h:$m $ap';
  }

  /// A row of quick facts under the stats: a scheduled-departure badge (when
  /// set) and the trip's length / the distance to the pickup.
  Widget _metaRow() {
    final chips = <Widget>[];
    if (ride.isScheduled) {
      chips.add(_metaChip(Icons.schedule_rounded, _scheduledLabel, accent: true));
    } else {
      chips.add(_metaChip(Icons.bolt_rounded, 'Leave now'));
    }
    if (ride.tripDistanceKm != null) {
      chips.add(_metaChip(Icons.straighten_rounded,
          '${ride.tripDistanceKm!.toStringAsFixed(1)} km trip'));
    }
    if (ride.tripDurationMin != null) {
      chips.add(_metaChip(Icons.access_time_rounded, '${ride.tripDurationMin} min'));
    }
    if (ride.distanceKm != null) {
      chips.add(_metaChip(Icons.near_me_rounded,
          '${ride.distanceKm!.toStringAsFixed(1)} km away'));
    }
    return Padding(
      padding: EdgeInsets.only(top: 12.h),
      child: Wrap(spacing: 8.w, runSpacing: 8.h, children: chips),
    );
  }

  Widget _metaChip(IconData icon, String label, {bool accent = false}) {
    final fg = accent ? Consonants.primaryColor : Consonants.greyColor;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: accent
            ? Consonants.lightBlueColor
            : Consonants.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.sp, color: fg),
          SizedBox(width: 4.w),
          CustomWidgets.customText(
              label, 10.5.sp, fg, FontWeight.w700, maxLines: 1),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: [
          BoxShadow(
            color: Consonants.primaryColor.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _hostStrip(),
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 16.h),
            child: Column(
              children: [
                _statsPills(),
                _metaRow(),
                SizedBox(height: 16.h),
                _actionButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Host strip (gradient top section) ──────────────────
  Widget _hostStrip() {
    final initial =
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : "?";
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Consonants.whiteColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.40),
                width: 2,
              ),
            ),
            child: Text(
              initial,
              style: TextStyle(
                color: Consonants.primaryColor,
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
                    CustomWidgets.customText(
                      "Trip Host",
                      9.sp,
                      Consonants.whiteColor.withValues(alpha: 0.85),
                      FontWeight.w700,
                    ),
                    SizedBox(width: 6.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: CustomWidgets.customText(
                        "Created the ride",
                        8.sp,
                        Consonants.whiteColor,
                        FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Flexible(
                      child: CustomWidgets.customText(
                        name,
                        14.sp,
                        Consonants.whiteColor,
                        FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 5.w),
                    Icon(Icons.verified_rounded,
                        size: 14.sp, color: Consonants.whiteColor),
                  ],
                ),
                SizedBox(height: 3.h),
                Row(
                  children: [
                    Icon(Icons.star_rounded,
                        size: 12.sp, color: const Color(0xffFFD54F)),
                    SizedBox(width: 3.w),
                    CustomWidgets.customText(
                      "$rating  ·  $trips trips",
                      10.sp,
                      Consonants.whiteColor.withValues(alpha: 0.95),
                      FontWeight.w600,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (hostGender == 'FEMALE' || hostGender == 'MALE')
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: Consonants.whiteColor,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hostGender == 'FEMALE'
                        ? Icons.female_rounded
                        : Icons.male_rounded,
                    size: 11.sp,
                    color: hostGender == 'FEMALE'
                        ? const Color(0xffEC4899)
                        : Consonants.primaryColor,
                  ),
                  SizedBox(width: 3.w),
                  CustomWidgets.customText(
                    hostGender == 'FEMALE' ? 'Female' : 'Male',
                    9.sp,
                    Consonants.boldTextColor,
                    FontWeight.w700,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── Stats: your fare / avg rating / riders ─────────────
  Widget _statsPills() {
    return Row(
      children: [
        Expanded(
          child: _statTile(
            icon: Icons.payments_rounded,
            value: yourFare,
            label: "Your fare",
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _statTile(
            icon: Icons.star_rounded,
            value: avgRating,
            label: "Avg rating",
            iconColor: const Color(0xffF5B800),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _statTile(
            icon: Icons.people_alt_rounded,
            value: "$riders",
            label: "Riders",
          ),
        ),
      ],
    );
  }

  Widget _statTile({
    required IconData icon,
    required String value,
    required String label,
    Color? iconColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 6.w),
      decoration: BoxDecoration(
        color: Consonants.lightBlueColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Icon(icon,
              size: 16.sp, color: iconColor ?? Consonants.primaryColor),
          SizedBox(height: 4.h),
          CustomWidgets.customText(
            value,
            12.sp,
            Consonants.boldTextColor,
            FontWeight.w800,
          ),
          CustomWidgets.customText(
            label,
            9.sp,
            Consonants.greyColor,
            FontWeight.w500,
          ),
        ],
      ),
    );
  }

  // ─── Action buttons (Decline + View Request) ───────────
  Widget _actionButtons() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onDecline,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 13.h),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Consonants.whiteColor,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: Consonants.lightGreyColor,
                  width: 1.5,
                ),
              ),
              child: CustomWidgets.customText(
                isMyRide ? (ride.youAreHost ? "Cancel" : "Leave") : "Decline",
                12.sp,
                isMyRide
                    ? const Color(0xffEF4444)
                    : Consonants.boldTextColor,
                FontWeight.w700,
              ),
            ),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: onViewRequest,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 13.h),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
                ),
                borderRadius: BorderRadius.circular(14.r),
                boxShadow: [
                  BoxShadow(
                    color: Consonants.primaryColor.withValues(alpha: 0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomWidgets.customText(
                    "View Request",
                    12.sp,
                    Consonants.whiteColor,
                    FontWeight.w800,
                  ),
                  SizedBox(width: 6.w),
                  Icon(Icons.arrow_forward_rounded,
                      size: 14.sp, color: Consonants.whiteColor),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
