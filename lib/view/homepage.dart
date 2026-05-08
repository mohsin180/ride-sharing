import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/mapProvider.dart';
import 'package:ride_sharing/provider/rideCreationProvider.dart';
import 'package:ride_sharing/provider/rideRequestProvider.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';
import 'package:ride_sharing/widgets/home/homeBookingSheet.dart';
import 'package:ride_sharing/widgets/home/homePickupPin.dart';

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
          const HomePickupPin(),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
              child: const _HomeHeader(),
            ),
          ),
          HomeBookingSheet(
            isBooking: isBooking,
            onBookPressed: isBooking ? null : _onBookPressed,
          ),
        ],
      ),
    );
  }

  Future<void> _onLocationResolved(LatLng location) async {
    final completer = ref.read(mapControllerCompleterProvider);
    final controller = await completer.future;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(location, kDefaultZoom),
    );
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
    );

    try {
      await ref.read(rideCreationProvider.notifier).createRide(request);
      // Navigation handled by ref.listen above.
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
        _CircleIconButton(
          icon: Icons.send_outlined,
          badge: true,
          onTap: () => context.push(Approutes.passengerMessages),
        ),
        SizedBox(width: 8.w),
        _CircleIconButton(
          icon: Icons.notifications_none_rounded,
          badge: true,
          onTap: () => context.push(Approutes.passengerNotification),
        ),
      ],
    );
  }
}

class _GreetingPill extends StatelessWidget {
  const _GreetingPill();

  @override
  Widget build(BuildContext context) {
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
              "M",
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
                      "Good morning,",
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
                  "Mohsin Karim",
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
// The GoogleMap widget itself never rebuilds: all props are const, and state
// flows outward via `ref.read` inside the callbacks. `onCameraMove` pushes the
// center coordinate into [pickupLocationProvider] so the pickup row reflects
// the pan in real time.
// ─────────────────────────────────────────────────────────────────────────────

class _MapLayer extends ConsumerWidget {
  const _MapLayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: kDefaultLatLng,
        zoom: kDefaultZoom,
      ),
      style: kMinimalMapStyle,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      compassEnabled: true,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      padding: EdgeInsets.only(
        top: 80.h,
        bottom: MediaQuery.of(context).size.height * 0.42,
      ),
      onMapCreated: (controller) {
        final completer = ref.read(mapControllerCompleterProvider);
        if (!completer.isCompleted) completer.complete(controller);
      },
      onCameraMove: (position) {
        ref.read(pickupLocationProvider.notifier).update(position.target);
      },
    );
  }
}
