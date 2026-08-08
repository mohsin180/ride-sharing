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
import 'package:ride_sharing/widgets/custom/appComponents.dart';
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

class _RidescreenState extends ConsumerState<Ridescreen> {
  late final TextEditingController _pickupController;
  late final TextEditingController _dropController;

  /// Rides the user dismissed ("not interested") this session — filtered out
  /// so they don't keep reappearing on refresh.
  final Set<String> _dismissed = {};

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
        color: Consonants.indigo,
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
          padding: EdgeInsets.only(bottom: Consonants.navClearance.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ScreenHeader(
                hasSearch: hasSearch,
                matchCount: committed ? myRides.length : filtered.length,
                isMyRidesTab: committed,
              ),
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
                  SizedBox(height: 14.h),
                  _radiusCaption(),
                ],
                SizedBox(height: 24.h),
                _buildBody(async, rides, filtered, hasSearch),
              ],
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
          if (i != rides.length - 1) SizedBox(height: Consonants.gapTiles.h),
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
      barrierColor: Consonants.scrim,
      builder: (dialogCtx) => _confirmDialog(
        dialogCtx,
        icon: Icons.logout_rounded,
        title: "Leave this ride?",
        body:
            "You'll be removed from this trip and can find another ride afterward.",
        confirmLabel: "Leave ride",
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
      barrierColor: Consonants.scrim,
      builder: (dialogCtx) => _confirmDialog(
        dialogCtx,
        icon: Icons.event_busy_outlined,
        title: "Cancel this ride?",
        body:
            "Any passengers who've joined will be notified. You can publish a new ride afterward.",
        confirmLabel: "Cancel ride",
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
      padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
      child: Row(
        children: [
          Icon(
            Icons.adjust_outlined,
            size: 15.sp,
            color: Consonants.iconInk,
          ),
          SizedBox(width: 8.w),
          Text(
            "Within ${_kRadiusKm.round()} km of your pickup",
            style: AppText.caption().copyWith(fontSize: 12.5.sp),
          ),
        ],
      ),
    );
  }

  /// Shared chrome for the two irreversible confirmations on this screen.
  /// Red is reserved for exactly this kind of action.
  Widget _confirmDialog(
    BuildContext dialogCtx, {
    required IconData icon,
    required String title,
    required String body,
    required String confirmLabel,
  }) {
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
              child: Icon(icon, size: 26.sp, color: Consonants.danger),
            ),
            SizedBox(height: 18.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.sectionHeading().copyWith(fontSize: 19.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppText.paragraph().copyWith(fontSize: 15.sp),
            ),
            SizedBox(height: 24.h),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: "Keep",
                    kind: AppButtonKind.neutral,
                    onPressed: () => Navigator.of(dialogCtx).pop(false),
                  ),
                ),
                SizedBox(width: Consonants.gapButtons.w),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(dialogCtx).pop(true),
                    child: Container(
                      alignment: Alignment.center,
                      padding:
                          EdgeInsets.symmetric(vertical: 17.h, horizontal: 12.w),
                      decoration: BoxDecoration(
                        color: Consonants.danger,
                        borderRadius:
                            BorderRadius.circular(Consonants.rButton.r),
                      ),
                      child: Text(
                        confirmLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.button(color: Consonants.surface)
                            .copyWith(fontSize: 16.sp),
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

    // Backend order is route-overlap / nearest-first, which is what we show.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Spacer(),
            _mapButton(filtered),
            SizedBox(width: Consonants.gutter.w),
          ],
        ),
        SizedBox(height: 18.h),
        for (int i = 0; i < filtered.length; i++) ...[
          _FeaturedRideCard(
            ride: filtered[i],
            onViewRequest: () => _onJoinRide(filtered[i]),
            onDecline: () {
              setState(() => _dismissed.add(filtered[i].id));
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  CustomWidgets.customErrorSnackBar("Ride dismissed"),
                );
            },
          ),
          if (i != filtered.length - 1) SizedBox(height: Consonants.gapTiles.h),
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
        height: 38.h,
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Consonants.chipBg,
          borderRadius: BorderRadius.circular(Consonants.rPill.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 16.sp, color: Consonants.iconInk),
            SizedBox(width: 6.w),
            Text(
              'Map',
              style: AppText.navLabel(color: Consonants.iconInk)
                  .copyWith(fontSize: 13.sp),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────── SEARCH FORM ───────────────────────
  Widget _searchForm() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
      child: AppCard(
        padding: EdgeInsets.fromLTRB(18.w, 6.h, 18.w, 18.h),
        child: Column(
          children: [
            // ─── Pickup field ───
            Row(
              children: [
                Container(
                  width: 14.w,
                  height: 14.w,
                  decoration: BoxDecoration(
                    color: Consonants.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: Consonants.indigo, width: 3),
                  ),
                ),
                SizedBox(width: 14.w),
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
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: const AppDivider(),
            ),
            // ─── Destination field ───
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 19.sp,
                  color: Consonants.iconInk,
                ),
                SizedBox(width: 10.w),
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
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: const AppDivider(),
            ),
            // ─── Seats counter ───
            Row(
              children: [
                Icon(
                  Icons.event_seat_outlined,
                  size: 19.sp,
                  color: Consonants.iconInk,
                ),
                SizedBox(width: 10.w),
                Text(
                  "Seats needed",
                  style: AppText.rowLabel().copyWith(fontSize: 15.5.sp),
                ),
                const Spacer(),
                _seatStepper(),
              ],
            ),
            SizedBox(height: 20.h),
            // ─── Save button ───
            AppButton(
              label: "Save",
              icon: Icons.bookmark_added_outlined,
              onPressed: _onSaveTap,
            ),
          ],
        ),
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
        hintStyle: AppText.rowLabel(color: Consonants.textMuted)
            .copyWith(fontSize: 15.5.sp),
        border: InputBorder.none,
        isCollapsed: true,
        contentPadding: EdgeInsets.symmetric(vertical: 6.h),
      ),
      textStyle: AppText.rowLabel(color: Consonants.headingInk)
          .copyWith(fontSize: 15.5.sp, fontWeight: FontWeight.w600),
      onPicked: (s) => onPicked(s.formatted, s.coords),
    );
  }

  Widget _seatStepper() {
    final seats = ref.watch(rideRequestProvider.select((s) => s.seats));
    final notifier = ref.read(rideRequestProvider.notifier);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: Consonants.chipBg,
        borderRadius: BorderRadius.circular(Consonants.rPill.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seatButton(
            Icons.remove_rounded,
            enabled: seats > 1,
            onTap: () => notifier.setSeats(seats - 1),
          ),
          SizedBox(width: 14.w),
          SizedBox(
            width: 16.w,
            child: Center(
              child: Text(
                "$seats",
                style: AppText.amount().copyWith(fontSize: 16.sp),
              ),
            ),
          ),
          SizedBox(width: 14.w),
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
        width: 28.w,
        height: 28.w,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? Consonants.indigo : Consonants.border,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 16.sp,
          color: enabled ? Consonants.surface : Consonants.textMuted,
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
    // The only subtitle worth showing is the match count — the prompt /
    // empty / error states below already say everything else.
    final subtitle = (!isMyRidesTab && hasSearch && matchCount > 0)
        ? (matchCount == 1 ? "1 nearby ride" : "$matchCount nearby rides")
        : null;
    final title = isMyRidesTab ? "Your Rides" : "Available Rides";

    return AppHeader(title: title, subtitle: subtitle);
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
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
      child: AppCard(
        padding: EdgeInsets.symmetric(vertical: 44.h, horizontal: 20.w),
        child: Column(
          children: [
            SizedBox(
              width: 28.w,
              height: 28.w,
              child: const CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Consonants.indigo,
              ),
            ),
            SizedBox(height: 18.h),
            Text(
              "Finding rides near you…",
              style: AppText.sectionHeading().copyWith(fontSize: 17.sp),
            ),
          ],
        ),
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
    return _emptyStateShell(
      icon: Icons.cloud_off_outlined,
      title: "Couldn't load rides",
      subtitle: message,
      iconBg: Consonants.dangerWash,
      iconColour: Consonants.danger,
      action: AppButton(
        label: "Try again",
        icon: Icons.refresh_rounded,
        kind: AppButtonKind.secondary,
        expand: false,
        onPressed: onRetry,
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
      icon: Icons.travel_explore_outlined,
      title:
          "Set pickup and destination to see rides within ${_kRadiusKm.round()} km",
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
      icon: Icons.location_off_outlined,
      title:
          "No rides within ${_kRadiusKm.round()} km of your pickup",
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
      icon: Icons.workspace_premium_outlined,
      title: "You haven't created any rides yet",
    );
  }
}

/// Shared chrome for empty-style states. Same card shape across
/// prompt / no-nearby / loading / error so the screen height doesn't
/// jump when transitioning between them.
Widget _emptyStateShell({
  required IconData icon,
  required String title,
  String? subtitle,
  Widget? action,
  Color iconBg = Consonants.indigoWash,
  Color iconColour = Consonants.indigo,
}) {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
    child: AppCard(
      padding: EdgeInsets.symmetric(vertical: 36.h, horizontal: 22.w),
      child: Column(
        children: [
          Container(
            width: 68.w,
            height: 68.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 30.sp, color: iconColour),
          ),
          SizedBox(height: 18.h),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.sectionHeading().copyWith(fontSize: 17.sp),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 8.h),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppText.paragraph().copyWith(fontSize: 15.sp),
            ),
          ],
          if (action != null) ...[
            SizedBox(height: 22.h),
            action,
          ],
        ],
      ),
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
    } else if (ride.isDeparted) {
      // Its slot has passed — saying "Leave now" here would be a lie.
      chips.add(_metaChip(Icons.history_rounded, 'Departed $_scheduledLabel'));
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
    final fg = accent ? Consonants.indigo : Consonants.textMuted;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: accent ? Consonants.indigoWash : Consonants.chipBg,
        borderRadius: BorderRadius.circular(Consonants.rPill.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: fg),
          SizedBox(width: 6.w),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.navLabel(color: fg).copyWith(fontSize: 12.5.sp),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
      child: AppCard(
        padding: EdgeInsets.all(18.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _hostStrip(),
            SizedBox(height: 20.h),
            _statsPills(),
            _metaRow(),
            SizedBox(height: 20.h),
            _actionButtons(),
          ],
        ),
      ),
    );
  }

  // ─── Host row ───────────────────────────────────────────
  Widget _hostStrip() {
    final initial =
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : "?";
    return Row(
      children: [
        Container(
          width: 48.w,
          height: 48.w,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Consonants.indigoWash,
            shape: BoxShape.circle,
          ),
          child: Text(
            initial,
            style: AppText.amount(color: Consonants.indigo)
                .copyWith(fontSize: 19.sp),
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
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.rowLabel(color: Consonants.headingInk)
                          .copyWith(fontSize: 16.5.sp,
                              fontWeight: FontWeight.w700),
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
                      "$rating  ·  $trips trips  ·  Trip host",
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
        if (hostGender == 'FEMALE' || hostGender == 'MALE') ...[
          SizedBox(width: 10.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Consonants.chipBg,
              borderRadius: BorderRadius.circular(Consonants.rPill.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hostGender == 'FEMALE'
                      ? Icons.female_outlined
                      : Icons.male_outlined,
                  size: 13.sp,
                  color: Consonants.iconInk,
                ),
                SizedBox(width: 4.w),
                Text(
                  hostGender == 'FEMALE' ? 'Female' : 'Male',
                  style: AppText.navLabel(color: Consonants.iconInk)
                      .copyWith(fontSize: 12.sp),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ─── The fare, and the two facts that qualify it ────────
  /// Money is the largest thing on the card it belongs to; the rating and
  /// rider count sit beside it as supporting detail, not as equals.
  Widget _statsPills() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Your fare",
                style: AppText.caption().copyWith(fontSize: 12.5.sp),
              ),
              SizedBox(height: 6.h),
              Text(
                yourFare,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.figure().copyWith(fontSize: 32.sp),
              ),
            ],
          ),
        ),
        SizedBox(width: 12.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _fact(Icons.star_outline_rounded, "$avgRating rating"),
            SizedBox(height: 8.h),
            _fact(Icons.people_outline_rounded, "$riders riders"),
          ],
        ),
      ],
    );
  }

  Widget _fact(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15.sp, color: Consonants.iconInk),
        SizedBox(width: 6.w),
        Text(label, style: AppText.caption().copyWith(fontSize: 13.sp)),
      ],
    );
  }

  // ─── Action buttons (Decline + View Request) ───────────
  Widget _actionButtons() {
    final declineLabel =
        isMyRide ? (ride.youAreHost ? "Cancel" : "Leave") : "Decline";
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onDecline,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 17.h, horizontal: 8.w),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Consonants.rButton.r),
                border: Border.all(
                  width: 1.5,
                  color: isMyRide ? Consonants.danger : Consonants.border,
                ),
              ),
              child: Text(
                declineLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.button(
                  color: isMyRide ? Consonants.danger : Consonants.bodyInk,
                ).copyWith(fontSize: 16.sp),
              ),
            ),
          ),
        ),
        SizedBox(width: Consonants.gapButtons.w),
        Expanded(
          flex: 2,
          child: AppButton(
            label: "View Request",
            onPressed: onViewRequest,
          ),
        ),
      ],
    );
  }
}
