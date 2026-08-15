import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/availableRidesProvider.dart';
import 'package:ride_sharing/provider/directionsProvider.dart';
import 'package:ride_sharing/provider/myRidesProvider.dart';
import 'package:ride_sharing/provider/providers.dart';
import 'package:ride_sharing/provider/rideDetailsProvider.dart';
import 'package:ride_sharing/provider/rideRequestProvider.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
import 'package:ride_sharing/widgets/custom/appComponents.dart';
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
    barrierColor: Consonants.scrim,
    builder: (ctx) => Dialog(
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
                Icons.event_busy_outlined,
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
              "This cancels the ride for everyone on it. This can't be undone.",
              textAlign: TextAlign.center,
              style: AppText.paragraph().copyWith(fontSize: 15.sp),
            ),
            SizedBox(height: 24.h),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: "Keep ride",
                    kind: AppButtonKind.neutral,
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                ),
                SizedBox(width: Consonants.gapButtons.w),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, true),
                    child: Container(
                      alignment: Alignment.center,
                      padding: EdgeInsets.symmetric(
                          vertical: 17.h, horizontal: 12.w),
                      decoration: BoxDecoration(
                        color: Consonants.danger,
                        borderRadius:
                            BorderRadius.circular(Consonants.rButton.r),
                      ),
                      child: Text(
                        "Cancel ride",
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

/// TRUE joiner fare preview (weighted share of the simulated new trip),
/// keyed by "rideId|pLat|pLng|dLat|dLng|seats" so identical params cache.
final _joinPreviewProvider = FutureProvider.autoDispose
    .family<JoinFarePreview, String>((ref, key) async {
  final p = key.split('|');
  return ref.read(rideServiceProvider).getJoinFarePreview(
        p[0],
        pickupLat: double.parse(p[1]),
        pickupLng: double.parse(p[2]),
        dropLat: double.parse(p[3]),
        dropLng: double.parse(p[4]),
        seats: int.parse(p[5]),
      );
});

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

    // Host vs searcher — the backend decides, since it knows who asked. This
    // used to compare the host's id against the in-memory auth state, which
    // holds a user id only after a login in THIS session: on any cold start it
    // was null, so the host of a ride was treated as a stranger and offered
    // "Confirm Ride" instead of "Publish to drivers".
    final isHost = details?.youAreHost ?? false;

    // Effective values — backend wins where available, navigator fallback
    // covers everything else. Seats = the VIEWER's own booking (yourSeats),
    // not the ride's total capacity, so the host sees the 2 they booked (not 4).
    final effSeats = details?.yourSeats ?? seats;

    // TRUE joiner fare preview — for a searcher (not host, not yet joined)
    // whose own route we know: their weighted share of the simulated new
    // trip, including their detour + seats. This is what they'd really pay.
    JoinFarePreview? joinPreview;
    final hasJoined = details?.youHaveJoined ?? false;
    if (rideId != null &&
        !isHost &&
        !hasJoined &&
        pickupLatLng != null &&
        dropLatLng != null) {
      joinPreview = ref
          .watch(_joinPreviewProvider(
              '${rideId!}|${pickupLatLng!.latitude}|${pickupLatLng!.longitude}'
              '|${dropLatLng!.latitude}|${dropLatLng!.longitude}|$seats'))
          .asData
          ?.value;
    }
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
      backgroundColor: Consonants.canvas,
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
                  color: Consonants.indigo,
                  onRefresh: () async {
                    if (rideId == null) return;
                    ref.invalidate(rideDetailsProvider(rideId!));
                    await ref.read(rideDetailsProvider(rideId!).future);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                        Consonants.gutter.w, 22.h, Consonants.gutter.w, 120.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _tripHostCard(details?.host, details?.createdAt),
                        SizedBox(height: Consonants.gapTiles.h),
                        _selectedRideCard(details?.rideType),
                        SizedBox(height: Consonants.gapTiles.h),
                        _statsRow(
                          seats: effSeats,
                          pickupLatLng: effPickupLatLng,
                          dropLatLng: effDropLatLng,
                          // Backend's FULL shared-route numbers (all riders'
                          // stops) — these grow as co-passengers join.
                          tripKm: details?.tripDistanceKm,
                          tripMin: details?.tripDurationMin,
                        ),
                        SizedBox(height: Consonants.gapTiles.h),
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
                        SizedBox(height: Consonants.gapTiles.h),
                        _fareCard(details?.fare, preview: joinPreview),
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
                              horizontal: 16.w, vertical: 11.h),
                          decoration: BoxDecoration(
                            color: Consonants.surface,
                            borderRadius:
                                BorderRadius.circular(Consonants.rPill.r),
                            boxShadow: Consonants.cardLift,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.close_rounded,
                                  size: 16.sp, color: Consonants.danger),
                              SizedBox(width: 6.w),
                              Text(
                                "Cancel ride",
                                style:
                                    AppText.navLabel(color: Consonants.danger)
                                        .copyWith(fontSize: 13.sp),
                              ),
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
                previewShare: joinPreview?.yourShare,
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
      decoration: const BoxDecoration(
        color: Consonants.surface,
        shape: BoxShape.circle,
        boxShadow: Consonants.cardLift,
      ),
      child: Icon(icon, color: Consonants.iconInk, size: 20.sp),
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

  return AppCard(
    padding: EdgeInsets.all(18.w),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Trip host",
              style: AppText.caption().copyWith(fontSize: 12.5.sp),
            ),
            const Spacer(),
            if (createdLabel.isNotEmpty)
              Text(
                "Created $createdLabel",
                style: AppText.caption().copyWith(fontSize: 12.sp),
              ),
          ],
        ),
        SizedBox(height: 14.h),
        Row(
          children: [
            Container(
              width: 50.w,
              height: 50.w,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Consonants.indigoWash,
                shape: BoxShape.circle,
              ),
              child: Text(
                initial,
                style: AppText.amount(color: Consonants.indigo)
                    .copyWith(fontSize: 20.sp),
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
                              .copyWith(
                                  fontSize: 16.5.sp,
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
                          "$ratingLabel  ·  $ridesLabel",
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
            if (host?.gender == 'FEMALE' || host?.gender == 'MALE') ...[
              SizedBox(width: 10.w),
              _genderChip(host!.gender!),
            ],
          ],
        ),
      ],
    ),
  );
}

/// Neutral chip — gender is a fact about the rider, not a status, so it
/// never takes a colour of its own.
Widget _genderChip(String gender) {
  final female = gender == 'FEMALE';
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
    decoration: BoxDecoration(
      color: Consonants.chipBg,
      borderRadius: BorderRadius.circular(Consonants.rPill.r),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          female ? Icons.female_outlined : Icons.male_outlined,
          size: 13.sp,
          color: Consonants.iconInk,
        ),
        SizedBox(width: 4.w),
        Text(
          female ? 'Female' : 'Male',
          style: AppText.navLabel(color: Consonants.iconInk)
              .copyWith(fontSize: 12.sp),
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
  final IconData icon;
  const _RideTier({
    required this.name,
    required this.icon,
  });
}

/// ───────────────────── SELECTED RIDE / VEHICLE CARD ─────────────────────
/// Shows the vehicle tier the passenger picked when creating the ride
/// (e.g. Premium / Economy). The tier label adapts to the backend
/// `rideType` enum; falls back to a neutral placeholder while loading.
Widget _selectedRideCard(String? rideType) {
  final tier = switch (rideType) {
    'PREMIUM' => const _RideTier(
        name: 'Premium',
        icon: Icons.directions_car_filled_rounded,
      ),
    'ECONOMY' => const _RideTier(
        name: 'Economy',
        icon: Icons.directions_car_filled_rounded,
      ),
    _ => const _RideTier(
        name: '—',
        icon: Icons.directions_car_filled_rounded,
      ),
  };

  return AppCard(
    padding: EdgeInsets.all(18.w),
    child: Row(
      children: [
        Container(
          width: 52.w,
          height: 52.w,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Consonants.indigoWash,
            borderRadius: BorderRadius.circular(Consonants.rCard.r),
          ),
          child: Icon(tier.icon, size: 26.sp, color: Consonants.indigo),
        ),
        SizedBox(width: 14.w),
        Expanded(
          child: Text(
            tier.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.sectionHeading().copyWith(fontSize: 18.sp),
          ),
        ),
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
              Icon(Icons.check_rounded, size: 12.sp, color: Consonants.iconInk),
              SizedBox(width: 4.w),
              Text(
                "Selected",
                style: AppText.navLabel(color: Consonants.iconInk)
                    .copyWith(fontSize: 12.sp),
              ),
            ],
          ),
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
  double? tripKm,
  int? tripMin,
}) {
  return Consumer(
    builder: (context, ref, _) {
      String duration = "—";
      String distance = "—";
      if (tripKm != null) {
        // Prefer the backend's FULL shared-route numbers (host + every
        // co-passenger's stops) — they grow as riders join. The client-side
        // directions call below only knows the host's direct pickup→drop.
        distance = "${tripKm.toStringAsFixed(1)} km";
        duration = tripMin != null ? "$tripMin min" : "—";
      } else if (pickupLatLng != null && dropLatLng != null) {
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
      return AppCard(
        padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 8.w),
        child: Row(
          children: [
            _statTile(duration, "Duration"),
            _statDivider(),
            _statTile(distance, "Distance"),
            _statDivider(),
            _statTile("$seats ${seats == 1 ? 'seat' : 'seats'}", "Booked"),
          ],
        ),
      );
    },
  );
}

Widget _statTile(String value, String label) {
  return Expanded(
    child: Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.sectionHeading().copyWith(fontSize: 18.sp),
        ),
        SizedBox(height: 5.h),
        Text(
          label,
          maxLines: 1,
          style: AppText.caption().copyWith(fontSize: 12.sp),
        ),
      ],
    ),
  );
}

Widget _statDivider() =>
    Container(height: 34.h, width: 1, color: Consonants.divider);

/// ───────────────────── CO-PASSENGERS CARD ─────────────────────
/// Compact roll-up of everyone (besides the host and the viewer) who
/// has joined this ride. Tapping it opens the full bottom sheet.
///
/// Copy flips on three axes:
///   - [isHost]:    host views — "passengers have joined" framing
///   - [hasJoined]: searcher who already joined — "You and N others"
///                  framing (without this, the card would say nobody has
///                  joined, because coPassengers excludes the viewer
///                  themselves, so count = 0)
///   - otherwise:   prospective joiner — "you'll share with N" framing
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
              0 => "No one has joined yet",
              1 => "You'll share with 1 other",
              _ => "You'll share with $count others",
            };
  // Only the names line earns a second row — with nobody aboard the
  // headline already says everything there is to say.
  final subtitle =
      coPassengers.isEmpty ? null : _coPassengersSubtitle(coPassengers);

  return AppCard(
    padding: EdgeInsets.all(18.w),
    child: Row(
      children: [
        _stackedPassengerAvatars(coPassengers),
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.rowLabel(color: Consonants.headingInk)
                    .copyWith(fontSize: 15.5.sp, fontWeight: FontWeight.w600),
              ),
              if (subtitle != null) ...[
                SizedBox(height: 4.h),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption().copyWith(fontSize: 12.5.sp),
                ),
              ],
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
/// at 3 visible. Each shows the passenger's initial on the brand wash;
/// when the list is empty, a single neutral "+" placeholder hints at the
/// join affordance.
Widget _stackedPassengerAvatars(List<RideCoPassenger> coPassengers) {
  if (coPassengers.isEmpty) {
    return Container(
      width: 36.w,
      height: 36.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Consonants.indigoWash,
        shape: BoxShape.circle,
        border: Border.all(color: Consonants.surface, width: 2.5),
      ),
      child: Icon(Icons.add_rounded, size: 18.sp, color: Consonants.indigo),
    );
  }
  final shown = coPassengers.take(3).toList(growable: false);
  return SizedBox(
    width: 36.w + (shown.length - 1) * 20.w,
    height: 36.w,
    child: Stack(
      children: List.generate(shown.length, (i) {
        return Positioned(
          left: (i * 20).w,
          child: Container(
            width: 36.w,
            height: 36.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Consonants.indigoWash,
              shape: BoxShape.circle,
              border: Border.all(color: Consonants.surface, width: 2.5),
            ),
            child: Text(
              shown[i].initial,
              style: AppText.amount(color: Consonants.indigo)
                  .copyWith(fontSize: 14.sp),
            ),
          ),
        );
      }),
    ),
  );
}

/// ───────────────────── FARE CARD ─────────────────────
/// One number, in plain rupees: what this viewer pays. Nothing else.
///
/// The card used to carry a caption, a whole-trip row, a "split by distance"
/// row and a payment note stacked beneath it. Every one of them was accurate
/// and none was being read — a figure this size, alone on the hero surface,
/// already says what it is.
///
/// A joiner's [preview] wins when present: the figure becomes what they'd
/// actually pay on the SIMULATED trip, their detour included. It still moves
/// whenever someone joins, since joining changes both the trip and the split.
Widget _fareCard(RideFareBreakdown? fare, {JoinFarePreview? preview}) {
  final totalLabel = preview != null
      ? preview.yourShareLabel
      : fare != null
          ? fare.format(fare.perRider)
          : '—';

  return HeroSurface(
    padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 22.h),
    child: Row(
      children: [
        Expanded(
          child: Text(
            totalLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.figure(color: Consonants.surface)
                .copyWith(fontSize: 36.sp),
          ),
        ),
        SizedBox(width: 12.w),
        Icon(
          Icons.account_balance_wallet_outlined,
          size: 18.sp,
          color: const Color(0xCCFFFFFF),
        ),
      ],
    ),
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

  /// The joiner's TRUE weighted share (from the fare preview) — wins over
  /// [fare.perRider] in the confirm label when present.
  final double? previewShare;
  final bool isHost;

  final bool hasJoined;
  final bool publishedToDrivers;
  final bool youHaveRequested;
  final bool detailsReady;

  const _BottomBar({
    required this.rideId,
    required this.fare,
    this.previewShare,
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
    // The bar floats over the scrolling content, so it's translucent
    // canvas over a blur — never an opaque slab.
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xC7F8F9FB),
            border: Border(top: BorderSide(color: Color(0x0D000000))),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  Consonants.gutter.w, 14.h, Consonants.gutter.w, 16.h),
              child: _buildButton(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton() {
    // Role unknown until details load — show a neutral placeholder rather
    // than risk offering the wrong action (e.g. "join" to the host).
    if (!widget.detailsReady) return _loadingChip();
    // Host: publish to drivers whenever they're ready, then wait. Works even
    // with co-passengers joined / seats full — a full group still needs a
    // driver. There is no "confirm" state for a host: booking already created
    // the ride, so this screen is only ever reached from Your Rides.
    if (widget.isHost) {
      return widget.publishedToDrivers ? _publishedChip() : _publishButton();
    }
    if (widget.hasJoined) return _leaveButton();
    // Backend-backed pending request (survives leaving/reopening the screen)
    // OR the optimistic flag set right after tapping, before the refetch.
    if (widget.youHaveRequested || _requestSent) return _requestSentChip();
    return _confirmButton();
  }

  /// Passive, non-actionable state of the bar — a wash-filled pill that
  /// reads as information, not as something to tap.
  Widget _statusChip({IconData? icon, String? label, bool spinner = false}) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 17.h, horizontal: 20.w),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Consonants.indigoWash,
        borderRadius: BorderRadius.circular(Consonants.rButton.r),
      ),
      child: spinner
          ? _spinner(Consonants.indigo)
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18.sp, color: Consonants.indigo),
                  SizedBox(width: 8.w),
                ],
                Flexible(
                  child: Text(
                    label ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.button(color: Consonants.indigo)
                        .copyWith(fontSize: 16.sp),
                  ),
                ),
              ],
            ),
    );
  }

  /// Shown while ride details are still loading — we don't yet know whether
  /// the viewer is the host, a member, or a prospective joiner, so we show a
  /// neutral, non-actionable placeholder instead of risking the wrong CTA.
  Widget _loadingChip() => _statusChip(spinner: true);

  /// Shown after a join request is sent — the host hasn't responded yet.
  Widget _requestSentChip() => _statusChip(
        icon: Icons.hourglass_top_outlined,
        label: "Request sent · waiting for host",
      );

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
    return AppButton(
      label: "Publish to drivers",
      icon: Icons.local_taxi_outlined,
      isLoading: _busy,
      onPressed: _onPublish,
    );
  }

  /// Host CTA after publishing — informational, waiting for a driver to
  /// accept. Cancellation still lives on the Your Rides tab.
  Widget _publishedChip() => _statusChip(
        icon: Icons.check_circle_outline_rounded,
        label: "Published · waiting for a driver",
      );

  Widget _leaveButton() {
    return GestureDetector(
      onTap: _busy ? null : _onPrimaryTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 17.h, horizontal: 20.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Consonants.rButton.r),
          border: Border.all(color: Consonants.danger, width: 1.5),
        ),
        child: _busy
            ? _spinner(Consonants.danger)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.logout_rounded,
                    size: 19.sp,
                    color: Consonants.danger,
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    "Leave Ride",
                    style: AppText.button(color: Consonants.danger)
                        .copyWith(fontSize: 17.5.sp),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _confirmButton() {
    final fare = widget.fare;
    // Prefer the joiner's true weighted preview share over the generic
    // per-rider average — this is what they'll actually be charged.
    final label = widget.previewShare != null
        ? "Confirm Ride · Rs ${widget.previewShare!.round()}"
        : fare != null
            ? "Confirm Ride · ${fare.format(fare.perRider)}"
            : "Confirm Ride";
    return AppButton(
      label: label,
      isLoading: _busy,
      onPressed: _onPrimaryTap,
    );
  }

  Widget _spinner(Color color) {
    return SizedBox(
      width: 22.h,
      height: 22.h,
      child: CircularProgressIndicator(
        strokeWidth: 2.4,
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
    barrierColor: Consonants.scrim,
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
  final title = isHost
      ? "Passengers"
      : hasJoined
          ? "Your ride-mates"
          : "Co-passengers";
  // With nobody aboard the empty state below already carries the message,
  // so the subtitle only shows when it has a count to report.
  final subtitle = passengers.isEmpty
      ? null
      : isHost
          ? "${passengers.length} joined your ride"
          : hasJoined
              ? "You and ${passengers.length} others are sharing this ride"
              : "${passengers.length} verified female · sharing your route";

  return Container(
    decoration: BoxDecoration(
      color: Consonants.surface,
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(Consonants.rSheet.r)),
      boxShadow: Consonants.sheetLift,
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.82,
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            Consonants.gutter.w, 16.h, Consonants.gutter.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: SheetHeader(title: title)),
                GestureDetector(
                  // Just dismiss this modal sheet — not go_router navigation,
                  // which could pop the whole screen or route home.
                  onTap: () => Navigator.of(context).pop(),
                  child: Padding(
                    padding: EdgeInsets.only(top: 12.h, left: 12.w),
                    child: Container(
                      width: 32.w,
                      height: 32.w,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Consonants.chipBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 17.sp,
                        color: Consonants.iconInk,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...[
              SizedBox(height: 6.h),
              Text(
                subtitle,
                style: AppText.caption().copyWith(fontSize: 13.sp),
              ),
            ],
            SizedBox(height: 12.h),
            if (passengers.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 48.h),
                child: Center(
                  child: Text(
                    hasJoined
                        ? "You're the only rider so far."
                        : "No one has joined yet.",
                    textAlign: TextAlign.center,
                    style: AppText.paragraph().copyWith(fontSize: 15.sp),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: passengers.length,
                  separatorBuilder: (_, __) => const AppDivider(),
                  itemBuilder: (_, i) => _coPassengerDetailCard(passengers[i]),
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
Widget _coPassengerDetailCard(RideCoPassenger p) {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: Consonants.rowVertical.h),
    child: Row(
      children: [
        Container(
          width: 46.w,
          height: 46.w,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Consonants.indigoWash,
            shape: BoxShape.circle,
          ),
          child: Text(
            p.initial,
            style: AppText.amount(color: Consonants.indigo)
                .copyWith(fontSize: 18.sp),
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
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.rowLabel().copyWith(fontSize: 16.sp),
                    ),
                  ),
                  SizedBox(width: 5.w),
                  Icon(
                    Icons.verified_outlined,
                    size: 14.sp,
                    color: Consonants.iconInk,
                  ),
                ],
              ),
              SizedBox(height: 3.h),
              Row(
                children: [
                  Icon(
                    Icons.star_outline_rounded,
                    size: 13.sp,
                    color: Consonants.textMuted,
                  ),
                  SizedBox(width: 4.w),
                  Flexible(
                    child: Text(
                      "${p.ratingLabel}  ·  ${p.trips} rides",
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
        if (p.gender == 'FEMALE' || p.gender == 'MALE') ...[
          SizedBox(width: 10.w),
          _genderChip(p.gender!),
        ],
      ],
    ),
  );
}
