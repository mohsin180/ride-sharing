import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/directionsProvider.dart';
import 'package:ride_sharing/provider/mapProvider.dart';
import 'package:ride_sharing/provider/messagingProvider.dart';
import 'package:ride_sharing/provider/myRidesProvider.dart';
import 'package:ride_sharing/provider/notificationProvider.dart';
import 'package:ride_sharing/provider/profileProvider.dart';
import 'package:ride_sharing/provider/rideCreationProvider.dart';
import 'package:ride_sharing/provider/rideRequestProvider.dart';
import 'package:ride_sharing/services/maps/mapTilesService.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';
import 'package:ride_sharing/widgets/home/homeBookingSheet.dart';

/// SafeRide home — real Google Map as background, fixed-center pickup pin,
/// floating header (greeting + messages + notification icons) and a
/// draggable booking sheet at the bottom.
///
/// State lives in Riverpod providers (see [mapProvider.dart]); widgets below
/// watch only the slices they care about so map panning doesn't rebuild
/// the whole tree.
class Homepage extends ConsumerStatefulWidget {
  const Homepage({super.key});

  @override
  ConsumerState<Homepage> createState() => _HomepageState();
}

class _HomepageState extends ConsumerState<Homepage> {
  @override
  void initState() {
    super.initState();
    // Wipe stale isSuccess/error from a prior booking so the listener
    // below only fires for *this* tab's tap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(rideCreationProvider.notifier).reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    // ref.listen subscribes the provider (triggering its build/GPS fetch)
    // without rebuilding this widget when the value changes.
    ref.listen<AsyncValue<LatLng>>(currentLocationProvider, (_, next) {
      next.whenOrNull(
        data: (location) => _onLocationResolved(location),
        error: (err, _) => ErrorHandler.show(context, err),
      );
    });

    // Surface ride-creation outcomes: errors → snackbar, success →
    // navigate to viewRequest with the freshly created ride payload.
    ref.listen<RideCreationState>(rideCreationProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ErrorHandler.show(context, next.error);
      } else if (next.isSuccess &&
          prev?.isSuccess != true &&
          next.ride != null) {
        final ride = next.ride!;
        ErrorHandler.success(context, "Ride requested. Finding drivers…");
        context.push(
          Approutes.viewRequest,
          extra: <String, dynamic>{
            'rideId': ride.id,
            'pickup': ride.pickup,
            'drop': ride.drop,
            'seats': ride.seats,
            'pickupLatLng': (ride.pickupLat != null && ride.pickupLng != null)
                ? LatLng(ride.pickupLat!, ride.pickupLng!)
                : null,
            'dropLatLng': (ride.dropLat != null && ride.dropLng != null)
                ? LatLng(ride.dropLat!, ride.dropLng!)
                : null,
          },
        );
      }
    });

    final isBooking = ref.watch(
      rideCreationProvider.select((s) => s.isLoading),
    );

    return Scaffold(
      body: Stack(
        children: [
          const _MapLayer(),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
              child: const _HomeHeader(),
            ),
          ),
          // "Recenter to my GPS fix" — anchored just above the booking
          // sheet's initial extent (0.42 of screen height). Replaces
          // Google Maps' built-in myLocationButton.
          Positioned(
            right: 16.w,
            bottom: MediaQuery.of(context).size.height * 0.42 + 14.h,
            child: const _MyLocationFab(),
          ),
          HomeBookingSheet(
            isBooking: isBooking,
            onBookPressed: isBooking ? null : _onBookPressed,
          ),
        ],
      ),
    );
  }

  /// Recenters the map on the freshly-resolved GPS fix and seeds the
  /// pickup pin. flutter_map's [MapController.move] is synchronous, so
  /// no completer dance — a stark improvement over the GoogleMap setup.
  void _onLocationResolved(LatLng location) {
    ref.read(mapControllerProvider).move(location, kDefaultZoom);
    ref.read(pickupLocationProvider.notifier).update(location);
  }

  Future<void> _onBookPressed() async {
    final pickup = ref.read(pickupLocationProvider);
    final rideReq = ref.read(rideRequestProvider);
    final selectedIndex = ref.read(selectedRideIndexProvider);

    if (pickup == null) {
      ErrorHandler.show(
        context,
        "We couldn't detect your pickup location yet. Please wait a moment and try again.",
      );
      return;
    }
    if (rideReq.drop.isEmpty || rideReq.dropLatLng == null) {
      ErrorHandler.show(
        context,
        "Please choose your drop-off location from the suggestions.",
      );
      return;
    }

    // One-active-ride guard. Force a fresh fetch so a cancellation that
    // happened on another tab is reflected — relying on cached data
    // could block the user even after they've already cancelled. On
    // network failure we let the request through; the backend still
    // enforces the same rule (409 Conflict) as the ultimate authority.
    ref.invalidate(myRidesProvider);
    try {
      final myActive = await ref.read(myRidesProvider.future);
      if (myActive.isNotEmpty) {
        if (!mounted) return;
        ErrorHandler.show(
          context,
          "You already have an active ride. Cancel it from the Rides tab before publishing a new one.",
        );
        return;
      }
    } catch (_) {
      // Fall through — backend will enforce.
    }

    // Resolve pickup text — prefer the reverse-geocoded address, fall
    // back to coords so the backend always gets something human-readable.
    final pickupAddress = ref
            .read(pickupAddressProvider)
            .whenOrNull(data: (a) => (a == null || a.isEmpty) ? null : a) ??
        '${pickup.latitude.toStringAsFixed(5)}, '
            '${pickup.longitude.toStringAsFixed(5)}';

    final request = CreateRideRequest(
      pickup: pickupAddress,
      drop: rideReq.drop,
      pickupLat: pickup.latitude,
      pickupLng: pickup.longitude,
      dropLat: rideReq.dropLatLng!.latitude,
      dropLng: rideReq.dropLatLng!.longitude,
      seats: rideReq.seats,
      rideType: kRideOptions[selectedIndex].title.toUpperCase(),
      departureTime: ref.read(scheduledDepartureProvider),
    );

    try {
      await ref.read(rideCreationProvider.notifier).createRide(request);
      // Clear the scheduled time so the next booking defaults to "leave now".
      ref.read(scheduledDepartureProvider.notifier).clear();
      // New ride means the host now has an active ride — wipe the
      // myRides cache so the next visit to the Your Rides tab (and
      // the next Book attempt's guard above) sees the freshly-created
      // ride. Navigation itself is handled by ref.listen above.
      ref.invalidate(myRidesProvider);
    } catch (_) {
      // Surfaced via state.error → ref.listen.
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME HEADER  — greeting pill on the left, message + notification icons
// on the right. Mirrors the driver homepage's `_Header` look so both flows
// feel like the same app, but wrapped in a white pill to stay readable
// over the GoogleMap background.
// ─────────────────────────────────────────────────────────────────────────────

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: _GreetingPill()),
        SizedBox(width: 10.w),
        Consumer(
          builder: (context, ref, _) {
            final unread = ref.watch(unreadMessagesCountProvider).maybeWhen(
                  data: (c) => c,
                  orElse: () => 0,
                );
            return _CircleIconButton(
              icon: Icons.send_outlined,
              badge: unread > 0,
              onTap: () => context.push(Approutes.passengerMessages),
            );
          },
        ),
        SizedBox(width: 8.w),
        Consumer(
          builder: (context, ref, _) {
            final unread = ref.watch(unreadCountProvider).maybeWhen(
                  data: (c) => c,
                  orElse: () => 0,
                );
            return _CircleIconButton(
              icon: Icons.notifications_none_rounded,
              badge: unread > 0,
              onTap: () => context.push(Approutes.passengerNotification),
            );
          },
        ),
      ],
    );
  }
}

class _GreetingPill extends ConsumerWidget {
  const _GreetingPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the cached passenger profile. Riverpod auto-fetches the
    // first time this provider is read; while we wait, fall back to a
    // generic "there" so the greeting still reads naturally instead of
    // flashing a placeholder.
    final profileAsync = ref.watch(passengerProfileProvider);
    final fullName = profileAsync.maybeWhen(
      data: (p) => p.fullName.trim(),
      orElse: () => '',
    );
    final displayName = fullName.isEmpty ? 'there' : fullName;
    final initial =
        fullName.isEmpty ? '?' : fullName.characters.first.toUpperCase();
    final greeting = _timeOfDayGreeting(DateTime.now().hour);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38.w,
            height: 38.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
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
              initial,
              style: TextStyle(
                fontFamily: Consonants.fontFamily,
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: Consonants.whiteColor,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CustomWidgets.customText(
                      "$greeting,",
                      10.sp,
                      Consonants.greyColor,
                      FontWeight.w500,
                    ),
                    SizedBox(width: 4.w),
                    CustomWidgets.customText(
                      "👋",
                      10.sp,
                      Consonants.greyColor,
                      FontWeight.w500,
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                CustomWidgets.customText(
                  displayName,
                  13.sp,
                  Consonants.boldTextColor,
                  FontWeight.w800,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "Good morning" / "afternoon" / "evening" based on the device clock.
  /// Cheaper and more friendly than a static label.
  String _timeOfDayGreeting(int hour) {
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final bool badge;
  final VoidCallback? onTap;

  const _CircleIconButton({
    required this.icon,
    this.badge = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Consonants.whiteColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, size: 20.sp, color: Consonants.boldTextColor),
          ),
          if (badge)
            Positioned(
              top: 6.h,
              right: 8.w,
              child: Container(
                width: 9.w,
                height: 9.w,
                decoration: BoxDecoration(
                  color: const Color(0xffEF4444),
                  shape: BoxShape.circle,
                  border: Border.all(color: Consonants.whiteColor, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Map layer — isolated so camera events don't rebuild the sheet / top bar.
//
// flutter_map (CartoDB Voyager raster tiles) replaces the previous GoogleMap.
// `onPositionChanged` pushes the center coordinate into [pickupLocationProvider]
// only when the user gestures, so programmatic recenter calls (from
// [_HomepageState._onLocationResolved]) don't echo back through the provider.
// ─────────────────────────────────────────────────────────────────────────────

class _MapLayer extends ConsumerWidget {
  const _MapLayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(mapControllerProvider);
    final currentLoc = ref.watch(currentLocationProvider).value;
    final pickup = ref.watch(pickupLocationProvider);
    final drop = ref.watch(rideRequestProvider.select((s) => s.dropLatLng));

    // Only request the route once both endpoints are known. Riverpod
    // caches per-DirectionsRequest, so panning to refine pickup hits
    // Geoapify again with the new origin. .value (vs .when) means the
    // polyline simply disappears during a re-route instead of flashing
    // a loading widget into the map's children list.
    final routePoints = (pickup != null && drop != null)
        ? ref
            .watch(directionsProvider(
              DirectionsRequest(origin: pickup, destination: drop),
            ))
            .value
            ?.points
        : null;

    // When a fresh destination lands, frame pickup→drop in the visible
    // map area (above the booking sheet) so the user immediately sees
    // both points and the route between them. Skips on null (cleared)
    // and on pure pickup-side pans.
    final mediaH = MediaQuery.of(context).size.height;
    ref.listen<LatLng?>(
      rideRequestProvider.select((s) => s.dropLatLng),
      (prev, next) {
        if (next == null || prev == next) return;
        final pickupNow = ref.read(pickupLocationProvider);
        if (pickupNow == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(mapControllerProvider).fitCamera(
                CameraFit.bounds(
                  bounds: LatLngBounds(pickupNow, next),
                  padding: EdgeInsets.fromLTRB(
                    48.w,
                    140.h,
                    48.w,
                    mediaH * 0.45,
                  ),
                ),
              );
        });
      },
    );

    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: kDefaultLatLng,
        initialZoom: kDefaultZoom,
        // Pinch-zoom + drag only — block tilt/rotate so the pickup pin
        // never lies about the coordinate it's "above".
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom |
              InteractiveFlag.drag |
              InteractiveFlag.doubleTapZoom |
              InteractiveFlag.flingAnimation,
        ),
        onPositionChanged: (camera, hasGesture) {
          if (!hasGesture) return;
          ref.read(pickupLocationProvider.notifier).update(camera.center);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: MapTilesService.tileUrl,
          subdomains: MapTilesService.subdomains,
          userAgentPackageName: MapTilesService.userAgentPackageName,
          // Cancellable provider drops in-flight tile requests when the
          // user pans away — keeps the network from filling with stale
          // images during fast pinch-zooms.
          tileProvider: CancellableNetworkTileProvider(),
        ),
        // Active route polyline. Renders only when both endpoints are
        // set and Geoapify has returned a path. Brief disappear while
        // a re-route is in flight is intentional — signals to the user
        // that the route is being recomputed.
        if (routePoints != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints,
                color: Consonants.primaryColor,
                strokeWidth: 4,
              ),
            ],
          ),
        // Pickup + destination markers, same circle-badge style as the
        // YourRide screens for visual consistency. Pickup tracks the
        // map center on every gesture (via onPositionChanged ↑) so it
        // visually stays anchored under the centre as the user pans.
        MarkerLayer(
          markers: [
            if (pickup != null)
              Marker(
                point: pickup,
                width: 32,
                height: 32,
                child: const _RouteMarker(
                  color: Color(0xff2196F3), // azure — pickup
                  icon: Icons.my_location_rounded,
                ),
              ),
            if (drop != null)
              Marker(
                point: drop,
                width: 32,
                height: 32,
                child: const _RouteMarker(
                  color: Color(0xffEF4444), // red — drop
                  icon: Icons.location_on_rounded,
                ),
              ),
          ],
        ),
        if (currentLoc != null)
          MarkerLayer(
            markers: [
              Marker(
                point: currentLoc,
                width: 22,
                height: 22,
                child: const _UserLocationDot(),
              ),
            ],
          ),
        const RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
            TextSourceAttribution('CARTO'),
          ],
        ),
      ],
    );
  }
}

/// "You are here" dot — replicates Google Maps' built-in blue location
/// marker so the user still has a visual anchor for their GPS fix.
class _UserLocationDot extends StatelessWidget {
  const _UserLocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: const DecoratedBox(
        decoration: BoxDecoration(
          color: Consonants.primaryColor,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Colored circle marker with an icon in the centre — same visual
/// language as the pickup/driver/drop pins on the YourRide screens.
/// Two-tone shadow gives it a slight float against the map tiles.
/// Caller-driven `color` + `icon` makes it reusable for start, drop,
/// or any other route waypoint.
class _RouteMarker extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _RouteMarker({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }
}

/// Floating action button that snaps the pickup pin to the user's GPS
/// fix. Replaces Google Maps' built-in `myLocationButton`. Just kicks
/// [CurrentLocationNotifier.refresh] — the homepage's `ref.listen` on
/// [currentLocationProvider] already takes care of moving the map and
/// seeding [pickupLocationProvider] when the new fix lands, plus
/// surfacing any error via the snackbar.
class _MyLocationFab extends ConsumerWidget {
  const _MyLocationFab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isResolving = ref.watch(
      currentLocationProvider.select((s) => s.isLoading),
    );

    return GestureDetector(
      onTap: isResolving
          ? null
          : () => ref.read(currentLocationProvider.notifier).refresh(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 46.w,
        height: 46.w,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Consonants.whiteColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Consonants.primaryColor.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: isResolving
            ? SizedBox(
                width: 18.w,
                height: 18.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Consonants.primaryColor,
                ),
              )
            : Icon(
                Icons.my_location_rounded,
                color: Consonants.primaryColor,
                size: 22.sp,
              ),
      ),
    );
  }
}
