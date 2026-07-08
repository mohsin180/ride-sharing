import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/services/maps/mapTilesService.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

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
                      width: 74,
                      height: 40,
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
          // Top bar
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
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: Consonants.whiteColor,
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: CustomWidgets.customText(
                      '$title · ${rides.length}',
                      13.sp,
                      Consonants.boldTextColor,
                      FontWeight.w800,
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
      child: Container(
        width: 42.w,
        height: 42.w,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Consonants.whiteColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, size: 20.sp, color: Consonants.boldTextColor),
      ),
    );
  }
}

/// A price "pin" marker — a rounded pill with the fare, blue for on-demand,
/// amber-accented when the ride is scheduled.
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
    final color =
        scheduled ? const Color(0xffB45309) : Consonants.primaryColor;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
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
                        size: 11.sp, color: Colors.white),
                  ),
                CustomWidgets.customText(
                    label, 11.sp, Colors.white, FontWeight.w800),
              ],
            ),
          ),
          Icon(Icons.arrow_drop_down, size: 14.sp, color: color),
        ],
      ),
    );
  }
}
