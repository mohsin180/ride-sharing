import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/provider/directionsProvider.dart';
import 'package:ride_sharing/provider/mapProvider.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

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

class Viewrequest extends StatelessWidget {
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
    this.pickup = "Hostel City, Block B",
    this.drop = "Taramri Chowk",
    this.seats = 1,
    this.pickupLatLng,
    this.dropLatLng,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // ─── Main column: fixed map + scrollable content ───
          Column(
            children: [
              _mapHeader(
                context,
                pickupLatLng: pickupLatLng,
                dropLatLng: dropLatLng,
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 110.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _tripHostCard(),
                      SizedBox(height: 12.h),
                      _selectedRideCard(),
                      SizedBox(height: 12.h),
                      _routeCard(pickup: pickup, drop: drop),
                      SizedBox(height: 12.h),
                      _statsRow(
                        seats: seats,
                        pickupLatLng: pickupLatLng,
                        dropLatLng: dropLatLng,
                      ),
                      SizedBox(height: 12.h),
                      GestureDetector(
                        onTap: () => _showCoPassengersSheet(context),
                        child: _coPassengersCard(),
                      ),
                      SizedBox(height: 12.h),
                      _fareCard(),
                    ],
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
                  ],
                ),
              ),
            ),
          ),

          // ─── Sticky bottom CTA bar ───
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _bottomBar(context),
          ),
        ],
      ),
    );
  }
}

/// ───────────────────── MAP HEADER ─────────────────────
Widget _mapHeader(
  BuildContext context, {
  LatLng? pickupLatLng,
  LatLng? dropLatLng,
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
      child: Stack(
        children: [
          Container(color: const Color(0xffE5E7EB)),
          const GoogleMap(
            initialCameraPosition: CameraPosition(
              target: kDefaultLatLng,
              zoom: 13.5,
            ),
            style: kMinimalMapStyle,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 48.h,
            child: Center(
              child: _etaChip(
                pickupLatLng: pickupLatLng,
                dropLatLng: dropLatLng,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Floating "X min · Y km" pill on the map. Watches [directionsProvider]
/// for the real road numbers when both coords are supplied; falls back
/// to the original demo label otherwise.
Widget _etaChip({LatLng? pickupLatLng, LatLng? dropLatLng}) {
  return Consumer(
    builder: (context, ref, _) {
      String label = "22 min · 12.4 km";
      if (pickupLatLng != null && dropLatLng != null) {
        ref
            .watch(directionsProvider(DirectionsRequest(
              origin: pickupLatLng,
              destination: dropLatLng,
            )))
            .whenData((r) {
          label = "${r.durationMinutes} min · "
              "${r.distanceKm.toStringAsFixed(1)} km";
        });
      }
      return _etaChipShell(label);
    },
  );
}

Widget _etaChipShell(String label) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
    decoration: BoxDecoration(
      color: Consonants.boldTextColor,
      borderRadius: BorderRadius.circular(30.r),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.20),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.access_time_rounded,
            color: Consonants.whiteColor, size: 13.sp),
        SizedBox(width: 6.w),
        CustomWidgets.customText(
          label,
          11.sp,
          Consonants.whiteColor,
          FontWeight.w700,
        ),
      ],
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
Widget _tripHostCard() {
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
            Icon(Icons.access_time_rounded,
                size: 11.sp, color: Consonants.greyColor),
            SizedBox(width: 3.w),
            CustomWidgets.customText(
              "Created 12m ago",
              10.sp,
              Consonants.greyColor,
              FontWeight.w500,
            ),
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
                "S",
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
                          "Sarah Ahmed",
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
                        "4.9",
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
                        "128 rides",
                        11.sp,
                        Consonants.greyColor,
                        FontWeight.w500,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: const Color(0xffFCE7F3),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.female_rounded,
                      size: 11.sp,
                      color: const Color(0xffEC4899)),
                  SizedBox(width: 3.w),
                  CustomWidgets.customText(
                    "Female",
                    9.sp,
                    const Color(0xffEC4899),
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

/// ───────────────────── SELECTED RIDE / VEHICLE CARD ─────────────────────
/// Shows the vehicle tier the passenger picked when creating the ride
/// (e.g. Premium / Comfort / Economy) along with key features.
Widget _selectedRideCard() {
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
                Icons.directions_car_filled_rounded,
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
                        "Premium",
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
                    "Spacious & comfortable",
                    10.sp,
                    Consonants.whiteColor.withValues(alpha: 0.90),
                    FontWeight.w500,
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Container(
          padding:
              EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
          decoration: BoxDecoration(
            color: Consonants.whiteColor.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _featureChip(Icons.event_seat_rounded, "4 seats"),
              _featureChip(Icons.ac_unit_rounded, "AC"),
              _featureChip(Icons.star_rounded, "Top-rated"),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _featureChip(IconData icon, String text) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12.sp, color: Consonants.whiteColor),
      SizedBox(width: 4.w),
      CustomWidgets.customText(
        text,
        10.sp,
        Consonants.whiteColor,
        FontWeight.w600,
      ),
    ],
  );
}

/// ───────────────────── ROUTE CARD ─────────────────────
Widget _routeCard({required String pickup, required String drop}) {
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
    padding: EdgeInsets.all(16.w),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CustomWidgets.customText(
              "Your Route",
              13.sp,
              Consonants.boldTextColor,
              FontWeight.w700,
            ),
            const Spacer(),
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: Consonants.primaryGreenColor,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: CustomWidgets.customText(
                "Shared ride",
                9.sp,
                const Color(0xff16A34A),
                FontWeight.w700,
              ),
            ),
          ],
        ),
        SizedBox(height: 14.h),
        _routeRow(
          dotColor: Consonants.primaryColor,
          label: "Pickup",
          place: pickup,
          time: "08:45 AM",
          showLine: true,
        ),
        SizedBox(height: 14.h),
        _routeRow(
          dotColor: const Color(0xffEF4444),
          label: "Destination",
          place: drop,
          time: "09:07 AM",
          showLine: false,
        ),
      ],
    ),
  );
}

Widget _routeRow({
  required Color dotColor,
  required String label,
  required String place,
  required String time,
  required bool showLine,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Column(
        children: [
          Container(
            width: 14.w,
            height: 14.w,
            decoration: BoxDecoration(
              color: Consonants.whiteColor,
              shape: BoxShape.circle,
              border: Border.all(color: dotColor, width: 3),
            ),
          ),
          if (showLine)
            Container(
              width: 2.w,
              height: 24.h,
              margin: EdgeInsets.symmetric(vertical: 2.h),
              color: Consonants.lightGreyColor,
            ),
        ],
      ),
      SizedBox(width: 12.w),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomWidgets.customText(
              label,
              9.sp,
              Consonants.greyColor,
              FontWeight.w600,
            ),
            SizedBox(height: 2.h),
            CustomWidgets.customText(
              place,
              12.sp,
              Consonants.boldTextColor,
              FontWeight.w700,
            ),
          ],
        ),
      ),
      Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: Consonants.lightBlueColor,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: CustomWidgets.customText(
          time,
          10.sp,
          Consonants.primaryColor,
          FontWeight.w700,
        ),
      ),
    ],
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
      String duration = "22 min";
      String distance = "12.4 km";
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
Widget _coPassengersCard() {
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
        _stackedPassengerAvatars(2),
        SizedBox(width: 14.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomWidgets.customText(
                "You'll share with 2 others",
                12.sp,
                Consonants.boldTextColor,
                FontWeight.w700,
              ),
              SizedBox(height: 2.h),
              CustomWidgets.customText(
                "Ayesha · Hina · all verified female",
                10.sp,
                Consonants.greyColor,
                FontWeight.w500,
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

Widget _stackedPassengerAvatars(int count) {
  const colors = [
    Color(0xffF472B6),
    Color(0xffFBBF24),
    Color(0xff60A5FA),
  ];
  return SizedBox(
    width: 36.w + (count - 1) * 18.w,
    height: 32.w,
    child: Stack(
      children: List.generate(count, (i) {
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
            child: Icon(Icons.person_rounded,
                size: 16.sp, color: Consonants.whiteColor),
          ),
        );
      }),
    ),
  );
}

/// ───────────────────── FARE CARD ─────────────────────
Widget _fareCard() {
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
        _fareRow("Base fare", "Rs 250", Consonants.boldTextColor),
        SizedBox(height: 8.h),
        _fareRow("Shared discount", "-Rs 50", const Color(0xff16A34A)),
        SizedBox(height: 8.h),
       
       
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
              "Rs 200",
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
              "Secure payment · Cash or card on arrival",
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
Widget _bottomBar(BuildContext context) {
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
        child: GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              CustomWidgets.customSuccessSnackBar(
                "Ride confirmed · Searching for driver",
              ),
            );
          },
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
                  color:
                      Consonants.primaryColor.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomWidgets.customText(
                  "Confirm Ride · Rs 200",
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
        ),
      ),
    ),
  );
}

/// ───────────────────── CO-PASSENGERS BOTTOM SHEET ─────────────────────
/// Shows full profile of every other passenger sharing the ride —
/// name, rating, rides, pickup and destination. The current user is
/// excluded from this list.
void _showCoPassengersSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => _coPassengersSheetContent(context),
  );
}

Widget _coPassengersSheetContent(BuildContext context) {
  final passengers = <_CoPassenger>[
    const _CoPassenger(
      initial: "A",
      color: Color(0xffF472B6),
      name: "Ayesha Khan",
      rating: "4.7",
      rides: "86",
      pickup: "Hostel City, Block A",
      drop: "Faizabad Metro",
    ),
    const _CoPassenger(
      initial: "H",
      color: Color(0xffFBBF24),
      name: "Hina Malik",
      rating: "4.9",
      rides: "142",
      pickup: "Bahria Phase 7",
      drop: "Taramri Chowk",
    ),
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
                        "Co-passengers",
                        17.sp,
                        Consonants.boldTextColor,
                        FontWeight.w800,
                      ),
                      SizedBox(height: 3.h),
                      CustomWidgets.customText(
                        "${passengers.length} verified female · sharing your route",
                        11.sp,
                        Consonants.greyColor,
                        FontWeight.w500,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _backOrHome(context),
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
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: passengers.length,
                separatorBuilder: (_, __) => SizedBox(height: 12.h),
                itemBuilder: (_, i) =>
                    _coPassengerDetailCard(passengers[i]),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CoPassenger {
  final String initial;
  final Color color;
  final String name;
  final String rating;
  final String rides;
  final String pickup;
  final String drop;

  const _CoPassenger({
    required this.initial,
    required this.color,
    required this.name,
    required this.rating,
    required this.rides,
    required this.pickup,
    required this.drop,
  });
}

Widget _coPassengerDetailCard(_CoPassenger p) {
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
      children: [
        Row(
          children: [
            Container(
              width: 48.w,
              height: 48.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Consonants.whiteColor,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: p.color.withValues(alpha: 0.30),
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
                        p.rating,
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
                        "${p.rides} rides",
                        11.sp,
                        Consonants.greyColor,
                        FontWeight.w500,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: const Color(0xffFCE7F3),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.female_rounded,
                      size: 11.sp,
                      color: const Color(0xffEC4899)),
                  SizedBox(width: 3.w),
                  CustomWidgets.customText(
                    "Female",
                    9.sp,
                    const Color(0xffEC4899),
                    FontWeight.w700,
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 14.h),
        Container(
          height: 1,
          color: Consonants.lightGreyColor,
        ),
        SizedBox(height: 12.h),
        _sheetRouteRow(
          dotColor: Consonants.primaryColor,
          label: "Pickup",
          place: p.pickup,
          showLine: true,
        ),
        SizedBox(height: 8.h),
        _sheetRouteRow(
          dotColor: const Color(0xffEF4444),
          label: "Destination",
          place: p.drop,
          showLine: false,
        ),
      ],
    ),
  );
}

Widget _sheetRouteRow({
  required Color dotColor,
  required String label,
  required String place,
  required bool showLine,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Column(
        children: [
          Container(
            width: 12.w,
            height: 12.w,
            decoration: BoxDecoration(
              color: Consonants.whiteColor,
              shape: BoxShape.circle,
              border: Border.all(color: dotColor, width: 2.5),
            ),
          ),
          if (showLine)
            Container(
              width: 2.w,
              height: 18.h,
              margin: EdgeInsets.symmetric(vertical: 2.h),
              color: Consonants.lightGreyColor,
            ),
        ],
      ),
      SizedBox(width: 10.w),
      Expanded(
        child: Padding(
          padding: EdgeInsets.only(top: 1.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomWidgets.customText(
                label,
                9.sp,
                Consonants.greyColor,
                FontWeight.w600,
              ),
              SizedBox(height: 1.h),
              CustomWidgets.customText(
                place,
                12.sp,
                Consonants.boldTextColor,
                FontWeight.w700,
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
