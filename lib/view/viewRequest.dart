import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/authProvider.dart';
import 'package:ride_sharing/provider/availableRidesProvider.dart';
import 'package:ride_sharing/provider/directionsProvider.dart';
import 'package:ride_sharing/provider/myRidesProvider.dart';
import 'package:ride_sharing/provider/providers.dart';
import 'package:ride_sharing/provider/rideDetailsProvider.dart';
import 'package:ride_sharing/provider/rideRequestProvider.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';
import 'package:ride_sharing/widgets/custom/floatingRequestBanner.dart';
import 'package:ride_sharing/widgets/custom/ratingSheet.dart';
import 'package:ride_sharing/widgets/custom/rideRouteMap.dart';

/// Pop the screen if there's something to go back to; otherwise fall
/// back to the bottom navbar so the back button is never a dead-end
/// (e.g. when [Viewrequest] is opened via a deep link).
void _backOrHome(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(Approutes.bottomNavbar);
  }
}

/// Host cancels the ride from the detail screen (works while PENDING or
/// ACCEPTED — even after it's created and a driver is assigned). Confirms
/// first, then refreshes the feeds and pops back.
Future<void> _confirmCancelRide(
    BuildContext context, WidgetRef ref, String rideId) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Cancel ride?"),
      content: const Text(
          "This cancels the ride for everyone on it. This can't be undone."),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Keep ride")),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Cancel ride")),
      ],
    ),
  );
  if (confirm != true) return;
  try {
    await ref.read(rideServiceProvider).cancelRide(rideId);
    ref.invalidate(rideDetailsProvider(rideId));
    ref.invalidate(availableRidesProvider);
    ref.invalidate(myRidesProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          CustomWidgets.customSuccessSnackBar("Ride cancelled"));
    _backOrHome(context);
  } catch (e) {
    if (context.mounted) ErrorHandler.show(context, e);
  }
}

class Viewrequest extends ConsumerWidget {
  /// Backend id of the ride being viewed. When provided we fetch the
  /// real ride details (host, co-passengers, fare); when null we fall
  /// back to whatever the navigator passed in via the other params —
  /// the "preview a freshly-composed ride" path from the homepage that
  /// hasn't been wired through the create endpoint yet.
  final String? rideId;

  final String pickup;
  final String drop;
  final int seats;

  /// Real coordinates for the pickup / drop. When both are non-null we
  /// hit the Directions API for the live distance + ETA pill in the
  /// floating header and the stats row; otherwise the screen falls
  /// back to a sensible static label.
  final LatLng? pickupLatLng;
  final LatLng? dropLatLng;

  const Viewrequest({
    super.key,
    this.rideId,
    this.pickup = "Hostel City, Block B",
    this.drop = "Taramri Chowk",
    this.seats = 1,
    this.pickupLatLng,
    this.dropLatLng,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Optimistic load — render the navigator-passed fallback values
    // immediately, swap in backend data the moment `rideDetailsProvider`
    // resolves. Errors leave `details` null so the screen still draws.
    final detailsAsync =
        rideId != null ? ref.watch(rideDetailsProvider(rideId!)) : null;
    final details = detailsAsync?.value;

    // Host vs searcher detection — same userId = this is the user's own
    // ride, otherwise they're viewing someone else's ride to join.
    final currentUserId =
        ref.watch(authControllerProvider.select((s) => s.userId));
    final isHost = currentUserId != null &&
        details != null &&
        details.host.id == currentUserId;

    // Effective values — backend wins where available, navigator fallback
    // covers everything else. Seats = the VIEWER's own booking (yourSeats),
    // not the ride's total capacity, so the host sees the 2 they booked (not 4).
    final effSeats = details?.yourSeats ?? seats;
    final effPickupLatLng = (details?.pickupLat != null &&
            details?.pickupLng != null)
        ? LatLng(details!.pickupLat!, details.pickupLng!)
        : pickupLatLng;
    final effDropLatLng =
        (details?.dropLat != null && details?.dropLng != null)
            ? LatLng(details!.dropLat!, details.dropLng!)
            : dropLatLng;

    // Stops for the route map: prefer the backend's full set (host + every
    // joined co-passenger's pickup/drop). Before details load — or on the
    // rideId-less preview path — fall back to a simple host A→B built from
    // the navigator coords so the map still shows something.
    final routeStops = (details != null && details.stops.isNotEmpty)
        ? details.stops
        : <RideStop>[
            if (effPickupLatLng != null)
              RideStop(
                ownerId: 'host',
                label: 'Pickup',
                kind: RideStopKind.pickup,
                lat: effPickupLatLng.latitude,
                lng: effPickupLatLng.longitude,
              ),
            if (effDropLatLng != null)
              RideStop(
                ownerId: 'host',
                label: 'Destination',
                kind: RideStopKind.drop,
                lat: effDropLatLng.latitude,
                lng: effDropLatLng.longitude,
              ),
          ];
    final routeHostId = details?.host.id ?? 'host';

    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // ─── Main column: fixed map + scrollable content ───
          Column(
            children: [
              _mapHeader(
                context,
                stops: routeStops,
                hostId: routeHostId,
                fallbackCenter: effPickupLatLng,
              ),
              Expanded(
                child: RefreshIndicator(
                  color: Consonants.primaryColor,
                  onRefresh: () async {
                    if (rideId == null) return;
                    ref.invalidate(rideDetailsProvider(rideId!));
                    await ref.read(rideDetailsProvider(rideId!).future);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 110.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _tripHostCard(details?.host, details?.createdAt),
                        SizedBox(height: 12.h),
                        _selectedRideCard(details?.rideType),
                        SizedBox(height: 12.h),
                        _statsRow(
                          seats: effSeats,
                          pickupLatLng: effPickupLatLng,
                          dropLatLng: effDropLatLng,
                        ),
                        SizedBox(height: 12.h),
                        GestureDetector(
                          onTap: () => _showCoPassengersSheet(
                            context,
                            details?.coPassengers ?? const [],
                            isHost: isHost,
                            hasJoined: details?.youHaveJoined ?? false,
                          ),
                          child: _coPassengersCard(
                            details?.coPassengers ?? const [],
                            isHost: isHost,
                            hasJoined: details?.youHaveJoined ?? false,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        _fareCard(details?.fare),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ─── Floating back button over the map ───
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 0),
                child: Row(
                  children: [
                    _circleIconButton(
                      Icons.arrow_back_rounded,
                      onTap: () => _backOrHome(context),
                    ),
                    const Spacer(),
                    // Host can cancel the ride at any point after creating it.
                    if (isHost && rideId != null)
                      GestureDetector(
                        onTap: () => _confirmCancelRide(context, ref, rideId!),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 14.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            color: const Color(0xffFEE2E2),
                            borderRadius: BorderRadius.circular(30.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.close_rounded,
                                  size: 15.sp, color: const Color(0xffEF4444)),
                              SizedBox(width: 6.w),
                              CustomWidgets.customText("Cancel ride", 12.sp,
                                  const Color(0xffEF4444), FontWeight.w800),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Sticky bottom CTA bar ───
          // Only shown when we actually have a ride id to act on —
          // deep-link / preview entries without a rideId can't join.
          if (rideId != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BottomBar(
                rideId: rideId!,
                fare: details?.fare,
                isHost: isHost,
                hasJoined: details?.youHaveJoined ?? false,
                publishedToDrivers: details?.publishedToDrivers ?? false,
                youHaveRequested: details?.youHaveRequested ?? false,
                // Until details resolve we don't know the viewer's role, so
                // the bar must not offer "join" — otherwise a host would
                // briefly see it on their own ride. Gate the CTA on this.
                detailsReady: details != null,
              ),
            ),

          // ─── Floating real-time request card (inDrive "Choose a driver"
          // style) — driver offers + co-passenger join requests float in over
          // the map with Accept/Decline. Only the host has pending requests,
          // so it naturally shows for them only.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.only(top: 64.h),
                child: const FloatingRequestBanner(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ───────────────────── MAP HEADER ─────────────────────
/// Shows the full shared-ride route: every pickup/drop as a labelled
/// marker (A, B, C…) in shortest-path order, joined by a road polyline.
/// Replaces the old text route cards.
Widget _mapHeader(
  BuildContext context, {
  required List<RideStop> stops,
  required String hostId,
  LatLng? fallbackCenter,
}) {
  final width = MediaQuery.of(context).size.width;
  return ClipRRect(
    borderRadius: BorderRadius.only(
      bottomLeft: Radius.elliptical(width / 2, 38.h),
      bottomRight: Radius.elliptical(width / 2, 38.h),
    ),
    child: SizedBox(
      height: 290.h,
      width: double.infinity,
      child: RideRouteMap(
        stops: stops,
        hostId: hostId,
        fallbackCenter: fallbackCenter,
      ),
    ),
  );
}

Widget _circleIconButton(IconData icon, {required VoidCallback onTap}) {
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
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: Consonants.boldTextColor, size: 18.sp),
    ),
  );
}

/// ───────────────────── TRIP HOST CARD ─────────────────────
/// The passenger who created / published this ride. Displayed above
/// the vehicle tier card so viewers know who's behind the trip.
/// Renders sensible placeholders when [host] is null (still loading
/// or no rideId was supplied) so the screen never flashes empty.
Widget _tripHostCard(RideHost? host, DateTime? createdAt) {
  final name = (host?.name.isNotEmpty ?? false) ? host!.name : 'Loading…';
  final initial = (host?.name.isNotEmpty ?? false)
      ? host!.name.trim()[0].toUpperCase()
      : '?';
  final ratingLabel = host?.ratingLabel ?? '—';
  final ridesLabel = host == null ? '—' : '${host.trips} rides';
  final createdLabel = createdAt != null ? _relativeTime(createdAt) : '';

  return Container(
    padding: EdgeInsets.all(14.w),
    decoration: BoxDecoration(
      color: Consonants.whiteColor,
      borderRadius: BorderRadius.circular(18.r),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CustomWidgets.customText(
              "Trip Host",
              11.sp,
              Consonants.greyColor,
              FontWeight.w600,
            ),
            const Spacer(),
            if (createdLabel.isNotEmpty) ...[
              Icon(Icons.access_time_rounded,
                  size: 11.sp, color: Consonants.greyColor),
              SizedBox(width: 3.w),
              CustomWidgets.customText(
                "Created $createdLabel",
                10.sp,
                Consonants.greyColor,
                FontWeight.w500,
              ),
            ],
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Container(
              width: 50.w,
              height: 50.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Consonants.lightBlueColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Consonants.primaryColor.withValues(alpha: 0.20),
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
                      Flexible(
                        child: CustomWidgets.customText(
                          name,
                          14.sp,
                          Consonants.boldTextColor,
                          FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 5.w),
                      Icon(Icons.verified_rounded,
                          size: 14.sp,
                          color: Consonants.primaryColor),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Icon(Icons.star_rounded,
                          size: 12.sp,
                          color: const Color(0xffF5B800)),
                      SizedBox(width: 3.w),
                      CustomWidgets.customText(
                        ratingLabel,
                        11.sp,
                        Consonants.boldTextColor,
                        FontWeight.w700,
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        width: 3.w,
                        height: 3.w,
                        decoration: const BoxDecoration(
                          color: Consonants.greyColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      CustomWidgets.customText(
                        ridesLabel,
                        11.sp,
                        Consonants.greyColor,
                        FontWeight.w500,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (host?.gender == 'FEMALE' || host?.gender == 'MALE')
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: host!.gender == 'FEMALE'
                      ? const Color(0xffFCE7F3)
                      : Consonants.lightBlueColor,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      host.gender == 'FEMALE'
                          ? Icons.female_rounded
                          : Icons.male_rounded,
                      size: 11.sp,
                      color: host.gender == 'FEMALE'
                          ? const Color(0xffEC4899)
                          : Consonants.primaryColor,
                    ),
                    SizedBox(width: 3.w),
                    CustomWidgets.customText(
                      host.gender == 'FEMALE' ? 'Female' : 'Male',
                      9.sp,
                      host.gender == 'FEMALE'
                          ? const Color(0xffEC4899)
                          : Consonants.primaryColor,
                      FontWeight.w700,
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

/// "12m ago" / "2h ago" / "3d ago" style age label for [_tripHostCard].
/// Capped at days; for older rides the label simply rolls forward.
String _relativeTime(DateTime when) {
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

/// Display bundle for one ride tier. Kept as a tiny value type so the
/// `switch` in [_selectedRideCard] reads cleanly and adding tiers
/// later is one extra arm.
class _RideTier {
  final String name;
  final String subtitle;
  final IconData icon;
  const _RideTier({
    required this.name,
    required this.subtitle,
    required this.icon,
  });
}

/// ───────────────────── SELECTED RIDE / VEHICLE CARD ─────────────────────
/// Shows the vehicle tier the passenger picked when creating the ride
/// (e.g. Premium / Economy) along with key features. Tier label and
/// subtitle adapt to the backend `rideType` enum; falls back to a
/// neutral placeholder while loading.
Widget _selectedRideCard(String? rideType) {
  final tier = switch (rideType) {
    'PREMIUM' => _RideTier(
        name: 'Premium',
        subtitle: 'Spacious & comfortable',
        icon: Icons.directions_car_filled_rounded,
      ),
    'ECONOMY' => _RideTier(
        name: 'Economy',
        subtitle: 'Affordable & efficient',
        icon: Icons.directions_car_filled_rounded,
      ),
    _ => const _RideTier(
        name: '—',
        subtitle: 'Loading ride type…',
        icon: Icons.directions_car_filled_rounded,
      ),
  };

  return Container(
    padding: EdgeInsets.all(14.w),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18.r),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
      ),
      boxShadow: [
        BoxShadow(
          color: Consonants.primaryColor.withValues(alpha: 0.25),
          blurRadius: 18,
          offset: const Offset(0, 8),
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
                color: Consonants.whiteColor.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Icon(
                tier.icon,
                size: 28.sp,
                color: Consonants.whiteColor,
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CustomWidgets.customText(
                        tier.name,
                        16.sp,
                        Consonants.whiteColor,
                        FontWeight.w800,
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 7.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color:
                              Consonants.whiteColor.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded,
                                size: 10.sp,
                                color: Consonants.whiteColor),
                            SizedBox(width: 2.w),
                            CustomWidgets.customText(
                              "Selected",
                              9.sp,
                              Consonants.whiteColor,
                              FontWeight.w700,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 3.h),
                  CustomWidgets.customText(
                    tier.subtitle,
                    10.sp,
                    Consonants.whiteColor.withValues(alpha: 0.90),
                    FontWeight.w500,
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

/// ───────────────────── STATS ROW ─────────────────────
///
/// When pickup + drop coordinates are present, the duration / distance
/// cells subscribe to [directionsProvider] for the real road numbers;
/// otherwise they fall back to the demo "22 min · 12.4 km" labels so
/// the screen still renders without coords (or before the API call
/// resolves).
Widget _statsRow({
  required int seats,
  LatLng? pickupLatLng,
  LatLng? dropLatLng,
}) {
  return Consumer(
    builder: (context, ref, _) {
      String duration = "—";
      String distance = "—";
      if (pickupLatLng != null && dropLatLng != null) {
        ref
            .watch(directionsProvider(DirectionsRequest(
              origin: pickupLatLng,
              destination: dropLatLng,
            )))
            .whenData((r) {
          duration = "${r.durationMinutes} min";
          distance = "${r.distanceKm.toStringAsFixed(1)} km";
        });
      }
      return Row(
        children: [
          Expanded(
            child: _statTile(
              Icons.access_time_rounded,
              duration,
              "Duration",
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _statTile(
              Icons.near_me_rounded,
              distance,
              "Distance",
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _statTile(
              Icons.event_seat_rounded,
              "$seats ${seats == 1 ? 'seat' : 'seats'}",
              "Booked",
            ),
          ),
        ],
      );
    },
  );
}

Widget _statTile(IconData icon, String value, String label) {
  return Container(
    padding: EdgeInsets.symmetric(vertical: 12.h),
    decoration: BoxDecoration(
      color: Consonants.whiteColor,
      borderRadius: BorderRadius.circular(14.r),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      children: [
        Icon(icon, size: 18.sp, color: Consonants.primaryColor),
        SizedBox(height: 4.h),
        CustomWidgets.customText(
          value,
          12.sp,
          Consonants.boldTextColor,
          FontWeight.w800,
        ),
        SizedBox(height: 1.h),
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

/// ───────────────────── CO-PASSENGERS CARD ─────────────────────
/// Compact roll-up of everyone (besides the host and the viewer) who
/// has joined this ride. Tapping it opens the full bottom sheet.
///
/// Copy flips on three axes:
///   - [isHost]:    host views — "passengers have joined" framing
///   - [hasJoined]: searcher who already joined — "You and N others"
///                  framing (without this, the card incorrectly says
///                  "Be the first to join" because coPassengers
///                  excludes the viewer themselves, so count = 0)
///   - otherwise:   prospective joiner — encouraging copy
Widget _coPassengersCard(
  List<RideCoPassenger> coPassengers, {
  required bool isHost,
  required bool hasJoined,
}) {
  final count = coPassengers.length;
  final headline = isHost
      ? switch (count) {
          0 => "No one has joined yet",
          1 => "1 passenger has joined",
          _ => "$count passengers have joined",
        }
      : hasJoined
          ? switch (count) {
              0 => "You've joined this ride",
              1 => "You and 1 other are sharing",
              _ => "You and $count others are sharing",
            }
          : switch (count) {
              0 => "Be the first to join this ride",
              1 => "You'll share with 1 other",
              _ => "You'll share with $count others",
            };
  final subtitle = coPassengers.isEmpty
      ? (isHost
          ? "Waiting for passengers"
          : hasJoined
              ? "You're the only rider so far"
              : "Tap to see ride details")
      : _coPassengersSubtitle(coPassengers);

  return Container(
    decoration: BoxDecoration(
      color: Consonants.whiteColor,
      borderRadius: BorderRadius.circular(18.r),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    padding: EdgeInsets.all(14.w),
    child: Row(
      children: [
        _stackedPassengerAvatars(coPassengers),
        SizedBox(width: 14.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomWidgets.customText(
                headline,
                12.sp,
                Consonants.boldTextColor,
                FontWeight.w700,
              ),
              SizedBox(height: 2.h),
              CustomWidgets.customText(
                subtitle,
                10.sp,
                Consonants.greyColor,
                FontWeight.w500,
                maxLines: 1,
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded,
            size: 20.sp, color: Consonants.greyColor),
      ],
    ),
  );
}

/// "Ayesha · Hina · all verified female" style line. Shows up to two
/// names; remaining count rolls into a "+N more" suffix.
String _coPassengersSubtitle(List<RideCoPassenger> coPassengers) {
  final firstNames = coPassengers
      .map((p) => p.name.split(' ').first)
      .where((n) => n.isNotEmpty)
      .toList();
  final shown = firstNames.take(2).join(' · ');
  final extra = firstNames.length - 2;
  final allFemale =
      coPassengers.every((p) => p.gender == 'FEMALE');
  final suffix = allFemale ? ' · all verified female' : '';
  if (extra > 0) return '$shown · +$extra more$suffix';
  return '$shown$suffix';
}

/// Stacked overlapping avatar circles — one per co-passenger, capped
/// at 3 visible. Each shows the passenger's initial; colour rotates
/// through a small palette for variety. When the list is empty, a
/// single neutral "+" placeholder hints at the join affordance.
Widget _stackedPassengerAvatars(List<RideCoPassenger> coPassengers) {
  const colors = [
    Color(0xffF472B6),
    Color(0xffFBBF24),
    Color(0xff60A5FA),
  ];
  if (coPassengers.isEmpty) {
    return Container(
      width: 32.w,
      height: 32.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Consonants.lightBlueColor,
        shape: BoxShape.circle,
        border: Border.all(color: Consonants.whiteColor, width: 2.5),
      ),
      child: Icon(Icons.add_rounded,
          size: 16.sp, color: Consonants.primaryColor),
    );
  }
  final shown = coPassengers.take(3).toList(growable: false);
  return SizedBox(
    width: 32.w + (shown.length - 1) * 18.w,
    height: 32.w,
    child: Stack(
      children: List.generate(shown.length, (i) {
        return Positioned(
          left: (i * 18).w,
          child: Container(
            width: 32.w,
            height: 32.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors[i % colors.length],
              shape: BoxShape.circle,
              border: Border.all(
                color: Consonants.whiteColor,
                width: 2.5,
              ),
            ),
            child: Text(
              shown[i].initial,
              style: TextStyle(
                color: Consonants.whiteColor,
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
                fontFamily: Consonants.fontFamily,
              ),
            ),
          ),
        );
      }),
    ),
  );
}

/// ───────────────────── FARE CARD ─────────────────────
/// Renders the fare breakdown coming from the backend. Falls back to
/// "—" placeholders while loading so the card always has the same
/// height and layout.
Widget _fareCard(RideFareBreakdown? fare) {
  final baseLabel = fare != null ? fare.format(fare.baseFare) : '—';
  final discountLabel = fare != null
      ? '-${fare.format(fare.sharedDiscount)}'
      : '—';
  final totalLabel = fare != null ? fare.format(fare.perRider) : '—';

  return Container(
    padding: EdgeInsets.all(16.w),
    decoration: BoxDecoration(
      color: Consonants.lightBlueColor,
      borderRadius: BorderRadius.circular(18.r),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CustomWidgets.customText(
              "Fare Breakdown",
              14.sp,
              Consonants.primaryColor,
              FontWeight.w700,
            ),
            const Spacer(),
            Icon(Icons.account_balance_wallet_rounded,
                size: 18.sp, color: Consonants.primaryColor),
          ],
        ),
        SizedBox(height: 14.h),
        _fareRow("Base fare", baseLabel, Consonants.boldTextColor),
        if (fare != null && fare.sharedDiscount > 0) ...[
          SizedBox(height: 8.h),
          _fareRow("Shared discount", discountLabel,
              const Color(0xff16A34A)),
        ],
        SizedBox(height: 12.h),
        Container(
          height: 1,
          color: Consonants.primaryColor.withValues(alpha: 0.15),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            CustomWidgets.customText(
              "You'll pay",
              14.sp,
              Consonants.boldTextColor,
              FontWeight.w800,
            ),
            const Spacer(),
            CustomWidgets.customText(
              totalLabel,
              22.sp,
              Consonants.primaryColor,
              FontWeight.w800,
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Row(
          children: [
            Icon(Icons.lock_rounded,
                size: 11.sp, color: Consonants.greyColor),
            SizedBox(width: 4.w),
            CustomWidgets.customText(
              "Secure payment · Cash on arrival",
              9.sp,
              Consonants.greyColor,
              FontWeight.w500,
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _fareRow(String label, String value, Color valueColor) {
  return Row(
    children: [
      CustomWidgets.customText(
        label,
        12.sp,
        Consonants.greyColor,
        FontWeight.w500,
      ),
      const Spacer(),
      CustomWidgets.customText(
        value,
        13.sp,
        valueColor,
        FontWeight.w700,
      ),
    ],
  );
}

/// ───────────────────── BOTTOM CTA BAR ─────────────────────
/// Three-state action bar at the bottom of viewRequest:
///   - **Host**:        disabled chip "You're hosting this ride"
///   - **Has joined**:  outlined red "Leave Ride"
///   - **Not joined**:  gradient "Confirm Ride · Rs N"
///
/// Owns its own `_busy` flag so the button shows a spinner during the
/// join/leave HTTP without forcing the parent to track per-action
/// loading state. On success, invalidates [rideDetailsProvider] (so
/// seats + co-passengers + youHaveJoined refresh) and
/// [availableRidesProvider] (so the search list reflects the new
/// seat count).
class _BottomBar extends ConsumerStatefulWidget {
  final String rideId;
  final RideFareBreakdown? fare;
  final bool isHost;
  final bool hasJoined;
  final bool publishedToDrivers;
  final bool youHaveRequested;
  final bool detailsReady;

  const _BottomBar({
    required this.rideId,
    required this.fare,
    required this.isHost,
    required this.hasJoined,
    required this.publishedToDrivers,
    required this.youHaveRequested,
    required this.detailsReady,
  });

  @override
  ConsumerState<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends ConsumerState<_BottomBar> {
  bool _busy = false;

  /// True once a join request has been sent (awaiting the host's response),
  /// so the CTA shows "Request sent" instead of letting them request again.
  bool _requestSent = false;

  Future<void> _onPrimaryTap() async {
    if (widget.isHost || _busy) return;
    setState(() => _busy = true);
    try {
      final service = ref.read(rideServiceProvider);
      if (widget.hasJoined) {
        // Snapshot who we rode with BEFORE leaving (the co-passenger list
        // refreshes without us afterwards) so we can rate them.
        final details = ref
            .read(rideDetailsProvider(widget.rideId))
            .maybeWhen(data: (d) => d, orElse: () => null);
        await service.leaveRide(widget.rideId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          CustomWidgets.customSuccessSnackBar("You left the ride"),
        );
        ref.invalidate(rideDetailsProvider(widget.rideId));
        ref.invalidate(availableRidesProvider);
        // Bidirectional leave-time rating: rate the co-passengers + driver
        // you rode with. (Remaining members are prompted to rate you via a
        // notification.)
        if (details != null && mounted) {
          await _promptLeaverRatings(details);
        }
        return;
      } else {
        // Send a join REQUEST (not an immediate join) carrying our own route
        // so the host can decide. The host accepts/declines via a notification.
        final req = ref.read(rideRequestProvider);
        await service.requestToJoin(
          widget.rideId,
          pickup: req.pickup.isNotEmpty ? req.pickup : null,
          pickupLat: req.pickupLatLng?.latitude,
          pickupLng: req.pickupLatLng?.longitude,
          drop: req.drop.isNotEmpty ? req.drop : null,
          dropLat: req.dropLatLng?.latitude,
          dropLng: req.dropLatLng?.longitude,
          // How many seats this co-passenger wants (from the search form).
          seats: req.seats,
        );
        if (!mounted) return;
        setState(() => _requestSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          CustomWidgets.customSuccessSnackBar(
            "Request sent — waiting for the host to accept",
          ),
        );
        return;
      }
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Walks the passenger who's leaving through rating each person they rode
  /// with: the host + co-passengers (co-passenger ratings), then the driver.
  /// Per-rating failures are skipped so one error doesn't abort the rest.
  Future<void> _promptLeaverRatings(RideDetails details) async {
    final people = <({String id, String name})>[
      (id: details.host.id, name: details.host.name),
      for (final c in details.coPassengers) (id: c.id, name: c.name),
    ];
    for (final p in people) {
      if (!mounted || p.id.isEmpty) continue;
      final name = p.name.trim().isEmpty ? 'co-passenger' : p.name.trim();
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
              .rateCoPassenger(widget.rideId, p.id, stars);
        } catch (_) {
          // Skip a failed rating and keep going.
        }
      }
    }

    // Rate the driver too, if one was assigned (active/completed ride).
    if (!mounted) return;
    final hasDriver = details.status == RideStatus.accepted ||
        details.status == RideStatus.started ||
        details.status == RideStatus.completed;
    if (hasDriver) {
      final stars = await showRatingSheet(
        context: context,
        title: 'Rate your driver',
        subtitle: 'How was your trip?',
      );
      if (stars != null) {
        try {
          await ref.read(rideServiceProvider).rateDriver(widget.rideId, stars);
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
          child: _buildButton(),
        ),
      ),
    );
  }

  Widget _buildButton() {
    // Role unknown until details load — show a neutral placeholder rather
    // than risk offering the wrong action (e.g. "join" to the host).
    if (!widget.detailsReady) return _loadingChip();
    // Host: publish the ride to drivers, then show a waiting state. Works even
    // with co-passengers already joined / seats full.
    if (widget.isHost) {
      return widget.publishedToDrivers ? _publishedChip() : _publishButton();
    }
    if (widget.hasJoined) return _leaveButton();
    // Backend-backed pending request (survives leaving/reopening the screen)
    // OR the optimistic flag set right after tapping, before the refetch.
    if (widget.youHaveRequested || _requestSent) return _requestSentChip();
    return _confirmButton();
  }

  /// Shown while ride details are still loading — we don't yet know whether
  /// the viewer is the host, a member, or a prospective joiner, so we show a
  /// neutral, non-actionable placeholder instead of risking the wrong CTA.
  Widget _loadingChip() {
    return Container(
      height: 54.h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14.r),
        color: Consonants.lightBlueColor,
      ),
      child: _spinner(Consonants.primaryColor),
    );
  }

  /// Shown after a join request is sent — the host hasn't responded yet.
  Widget _requestSentChip() {
    return Container(
      height: 54.h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14.r),
        color: Consonants.lightBlueColor,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hourglass_top_rounded,
            size: 16.sp,
            color: Consonants.primaryColor,
          ),
          SizedBox(width: 8.w),
          CustomWidgets.customText(
            "Request sent · waiting for host",
            13.sp,
            Consonants.primaryColor,
            FontWeight.w800,
          ),
        ],
      ),
    );
  }

  /// Host publishes the ride to the driver feed. Available even with
  /// co-passengers already joined / seats full — a full group still needs a
  /// driver. On success the CTA flips to [_publishedChip].
  Future<void> _onPublish() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(rideServiceProvider).publishRide(widget.rideId);
      ref.invalidate(rideDetailsProvider(widget.rideId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        CustomWidgets.customSuccessSnackBar(
          "Published — drivers can now see your ride",
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Host CTA before publishing — pushes the ride to the driver feed.
  Widget _publishButton() {
    return GestureDetector(
      onTap: _busy ? null : _onPublish,
      child: Container(
        height: 54.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14.r),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
          ),
          boxShadow: [
            BoxShadow(
              color: Consonants.primaryColor.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: _busy
            ? _spinner(Consonants.whiteColor)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_taxi_rounded,
                      size: 16.sp, color: Consonants.whiteColor),
                  SizedBox(width: 8.w),
                  CustomWidgets.customText(
                    "Publish to drivers",
                    14.sp,
                    Consonants.whiteColor,
                    FontWeight.w800,
                  ),
                ],
              ),
      ),
    );
  }

  /// Host CTA after publishing — informational, waiting for a driver to
  /// accept. Cancellation still lives on the Your Rides tab.
  Widget _publishedChip() {
    return Container(
      height: 54.h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14.r),
        color: Consonants.lightBlueColor,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 16.sp,
            color: Consonants.primaryColor,
          ),
          SizedBox(width: 8.w),
          CustomWidgets.customText(
            "Published · waiting for a driver",
            13.sp,
            Consonants.primaryColor,
            FontWeight.w800,
          ),
        ],
      ),
    );
  }

  Widget _leaveButton() {
    return GestureDetector(
      onTap: _busy ? null : _onPrimaryTap,
      child: Container(
        height: 54.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14.r),
          color: Consonants.whiteColor,
          border: Border.all(
            color: const Color(0xffFEE2E2),
            width: 1.5,
          ),
        ),
        child: _busy
            ? _spinner(const Color(0xffEF4444))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded,
                      size: 16.sp, color: const Color(0xffEF4444)),
                  SizedBox(width: 8.w),
                  CustomWidgets.customText(
                    "Leave Ride",
                    14.sp,
                    const Color(0xffEF4444),
                    FontWeight.w800,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _confirmButton() {
    final fare = widget.fare;
    final label = fare != null
        ? "Confirm Ride · ${fare.format(fare.perRider)}"
        : "Confirm Ride";
    return GestureDetector(
      onTap: _busy ? null : _onPrimaryTap,
      child: Container(
        height: 54.h,
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
              color: Consonants.primaryColor.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: _busy
            ? _spinner(Consonants.whiteColor)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomWidgets.customText(
                    label,
                    14.sp,
                    Consonants.whiteColor,
                    FontWeight.w800,
                  ),
                  SizedBox(width: 8.w),
                  Icon(Icons.arrow_forward_rounded,
                      size: 16.sp, color: Consonants.whiteColor),
                ],
              ),
      ),
    );
  }

  Widget _spinner(Color color) {
    return SizedBox(
      width: 22.h,
      height: 22.h,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: color,
      ),
    );
  }
}

/// ───────────────────── CO-PASSENGERS BOTTOM SHEET ─────────────────────
/// Shows full profile of every other passenger sharing the ride —
/// name, rating, rides. The current user and the host are excluded
/// from the backend-supplied list.
///
/// Copy adapts on viewer role:
///   - [isHost]:    "Passengers" framing — observing who joined
///   - [hasJoined]: "Your ride-mates" framing — they're already in
///   - otherwise:   "Co-passengers sharing your route" — prospective
void _showCoPassengersSheet(
  BuildContext context,
  List<RideCoPassenger> coPassengers, {
  required bool isHost,
  required bool hasJoined,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => _coPassengersSheetContent(
      context,
      coPassengers,
      isHost: isHost,
      hasJoined: hasJoined,
    ),
  );
}

Widget _coPassengersSheetContent(
  BuildContext context,
  List<RideCoPassenger> passengers, {
  required bool isHost,
  required bool hasJoined,
}) {
  // Stable per-list-position colour for each avatar; rotates through
  // a small palette so two rows next to each other never collide.
  const colors = [
    Color(0xffF472B6),
    Color(0xffFBBF24),
    Color(0xff60A5FA),
  ];

  return Container(
    decoration: BoxDecoration(
      color: Consonants.scaffoldBackgroundColor,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.80,
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Consonants.lightGreyColor,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 18.h),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomWidgets.customText(
                        isHost
                            ? "Passengers"
                            : hasJoined
                                ? "Your ride-mates"
                                : "Co-passengers",
                        17.sp,
                        Consonants.boldTextColor,
                        FontWeight.w800,
                      ),
                      SizedBox(height: 3.h),
                      CustomWidgets.customText(
                        isHost
                            ? (passengers.isEmpty
                                ? "Waiting for passengers to join"
                                : "${passengers.length} joined your ride")
                            : hasJoined
                                ? (passengers.isEmpty
                                    ? "You're the only rider so far"
                                    : "You and ${passengers.length} others are sharing this ride")
                                : "${passengers.length} verified female · sharing your route",
                        11.sp,
                        Consonants.greyColor,
                        FontWeight.w500,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  // Just dismiss this modal sheet — not go_router navigation,
                  // which could pop the whole screen or route home.
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 32.w,
                    height: 32.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Consonants.lightGreyColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded,
                        size: 16.sp,
                        color: Consonants.boldTextColor),
                  ),
                ),
              ],
            ),
            SizedBox(height: 18.h),
            if (passengers.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 40.h),
                child: Center(
                  child: CustomWidgets.customText(
                    isHost
                        ? "No one has joined yet."
                        : hasJoined
                            ? "You're the only rider so far."
                            : "Nobody has joined yet — be the first.",
                    12.sp,
                    Consonants.greyColor,
                    FontWeight.w500,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: passengers.length,
                  separatorBuilder: (_, __) => SizedBox(height: 12.h),
                  itemBuilder: (_, i) => _coPassengerDetailCard(
                    passengers[i],
                    colors[i % colors.length],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// One row in the co-passengers sheet — avatar with initial, name,
/// rating + trip count, and a small gender chip. All co-passengers
/// share the same ride, so per-passenger pickup/drop rows were
/// dropped intentionally (they'd just repeat the host's route).
Widget _coPassengerDetailCard(RideCoPassenger p, Color color) {
  final ratingLabel = p.ratingLabel;
  return Container(
    padding: EdgeInsets.all(14.w),
    decoration: BoxDecoration(
      color: Consonants.whiteColor,
      borderRadius: BorderRadius.circular(18.r),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 48.w,
          height: 48.w,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Consonants.whiteColor,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.30),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            p.initial,
            style: TextStyle(
              color: Consonants.whiteColor,
              fontSize: 18.sp,
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
                      p.name,
                      14.sp,
                      Consonants.boldTextColor,
                      FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 5.w),
                  Icon(Icons.verified_rounded,
                      size: 13.sp,
                      color: Consonants.primaryColor),
                ],
              ),
              SizedBox(height: 3.h),
              Row(
                children: [
                  Icon(Icons.star_rounded,
                      size: 12.sp,
                      color: const Color(0xffF5B800)),
                  SizedBox(width: 3.w),
                  CustomWidgets.customText(
                    ratingLabel,
                    11.sp,
                    Consonants.boldTextColor,
                    FontWeight.w700,
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    width: 3.w,
                    height: 3.w,
                    decoration: const BoxDecoration(
                      color: Consonants.greyColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  CustomWidgets.customText(
                    "${p.trips} rides",
                    11.sp,
                    Consonants.greyColor,
                    FontWeight.w500,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (p.gender == 'FEMALE' || p.gender == 'MALE')
          Container(
            padding:
                EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: p.gender == 'FEMALE'
                  ? const Color(0xffFCE7F3)
                  : Consonants.lightBlueColor,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  p.gender == 'FEMALE'
                      ? Icons.female_rounded
                      : Icons.male_rounded,
                  size: 11.sp,
                  color: p.gender == 'FEMALE'
                      ? const Color(0xffEC4899)
                      : Consonants.primaryColor,
                ),
                SizedBox(width: 3.w),
                CustomWidgets.customText(
                  p.gender == 'FEMALE' ? 'Female' : 'Male',
                  9.sp,
                  p.gender == 'FEMALE'
                      ? const Color(0xffEC4899)
                      : Consonants.primaryColor,
                  FontWeight.w700,
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

