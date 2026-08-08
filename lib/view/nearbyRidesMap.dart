import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/services/maps/mapTilesService.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';

/// Full-screen map of nearby rides: each ride's pickup is a tappable fare pin.
/// Tapping one pops the map and hands the ride back to the caller (which opens
/// its details / view-request). Shared by the passenger find screen and the
/// driver feed — pass the list and a per-ride tap handler.
class NearbyRidesMapScreen extends StatelessWidget {
  final List<AvailableRide> rides;
  final void Function(AvailableRide ride) onTapRide;
  final String title;

  const NearbyRidesMapScreen({
    super.key,
    required this.rides,
    required this.onTapRide,
    this.title = 'Nearby rides',
  });

  LatLng get _center {
    if (rides.isEmpty) return const LatLng(33.6844, 73.0479); // Islamabad
    double lat = 0, lng = 0;
    for (final r in rides) {
      lat += r.pickupLat;
      lng += r.pickupLng;
    }
    return LatLng(lat / rides.length, lng / rides.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Consonants.canvas,
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 12.5,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom |
                    InteractiveFlag.drag |
                    InteractiveFlag.doubleTapZoom |
                    InteractiveFlag.flingAnimation,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: MapTilesService.tileUrl,
                subdomains: MapTilesService.subdomains,
                userAgentPackageName: MapTilesService.userAgentPackageName,
                tileProvider: CancellableNetworkTileProvider(),
              ),
              MarkerLayer(
                markers: [
                  for (final r in rides)
                    Marker(
                      point: LatLng(r.pickupLat, r.pickupLng),
                      // Scaled like the pin's own padding and type, which are
                      // in .w/.sp — a fixed 74x40 box overflowed the pill plus
                      // its arrow on taller-density screens.
                      width: 96.w,
                      height: 52.h,
                      child: _FarePin(
                        label: r.fareForRider != null
                            ? 'Rs ${r.fareForRider!.round()}'
                            : 'Ride',
                        scheduled: r.isScheduled,
                        onTap: () {
                          Navigator.of(context).pop();
                          onTapRide(r);
                        },
                      ),
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
          ),
          // Top bar — floats over live tiles, so translucent canvas + blur.
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
              child: Row(
                children: [
                  _circleButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  SizedBox(width: 10.w),
                  Flexible(
                    child: _FloatingSurface(
                      radius: BorderRadius.circular(Consonants.rPill.r),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16.w, vertical: 9.h),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.rowLabel(
                                      color: Consonants.headingInk)
                                  .copyWith(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w600),
                            ),
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: Consonants.chipBg,
                                borderRadius:
                                    BorderRadius.circular(Consonants.rPill.r),
                              ),
                              child: Text(
                                '${rides.length}',
                                style: AppText.navLabel(
                                        color: Consonants.iconInk)
                                    .copyWith(fontSize: 11.sp),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: _FloatingSurface(
        radius: BorderRadius.circular(Consonants.rPill.r),
        child: SizedBox(
          width: 42.w,
          height: 42.w,
          child: Icon(icon, size: 20.sp, color: Consonants.iconInk),
        ),
      ),
    );
  }
}

/// Translucent canvas over a blur with the violet-tinted lift — the treatment
/// every control that floats over the map shares.
class _FloatingSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius radius;

  const _FloatingSurface({required this.child, required this.radius});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: Consonants.cardLift,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Consonants.canvas.withValues(alpha: 0.86),
              borderRadius: radius,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A price "pin" marker — a rounded pill carrying the fare. Indigo for
/// on-demand, violet when the ride is scheduled; the marker box stays 74x40
/// so the tip keeps landing on the pickup coordinate.
class _FarePin extends StatelessWidget {
  final String label;
  final bool scheduled;
  final VoidCallback onTap;
  const _FarePin({
    required this.label,
    required this.scheduled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = scheduled ? Consonants.violet : Consonants.indigo;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(Consonants.rPill.r),
              border: Border.all(color: Consonants.surface, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x402B2260),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (scheduled)
                  Padding(
                    padding: EdgeInsets.only(right: 3.w),
                    child: Icon(Icons.schedule_rounded,
                        size: 11.sp, color: Consonants.surface),
                  ),
                Text(
                  label,
                  style: AppText.amount(color: Consonants.surface)
                      .copyWith(fontSize: 11.sp),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_drop_down, size: 14.sp, color: color),
        ],
      ),
    );
  }
}
