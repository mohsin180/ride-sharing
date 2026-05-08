import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

/// Passenger-side ride-history screen. Mirrors [DriverRideHistory] in look
/// and structure (top bar, gradient summary strip, scrollable list of
/// rounded cards) but the content is what a *passenger* cares about:
///   • Pickup + drop-off addresses
///   • Date + time
///   • Status (Completed / Cancelled)
///   • Fare paid, driver + car, rating you gave
///
/// Reachable from the passenger profile's "Ride History" action via the
/// public [History] wrapper widget — preserved for backward-compat with
/// the existing profile call site.
class History extends StatelessWidget {
  const History({super.key, this.isPassenger = true});
  final bool isPassenger;

  @override
  Widget build(BuildContext context) {
    return const Passengerhistory();
  }
}

class Passengerhistory extends StatelessWidget {
  const Passengerhistory({super.key});

  static final List<_PassengerRide> _rides = [
    _PassengerRide(
      pickup: "Hostel City, Block B",
      dropOff: "Taramri Chowk",
      date: "12 Apr",
      time: "09:22",
      status: _RideStatus.completed,
      fare: 250,
      driverName: "Ali Raza",
      carInfo: "Toyota · White",
      ratingGiven: 4.9,
    ),
    _PassengerRide(
      pickup: "Bahria Phase 7",
      dropOff: "Faizabad Metro",
      date: "11 Apr",
      time: "18:05",
      status: _RideStatus.completed,
      fare: 180,
      driverName: "Usman Khan",
      carInfo: "Honda · Silver",
      ratingGiven: 5.0,
    ),
    _PassengerRide(
      pickup: "G-9 Markaz",
      dropOff: "Saddar",
      date: "10 Apr",
      time: "07:40",
      status: _RideStatus.cancelled,
      fare: 0,
      driverName: "—",
      carInfo: "—",
      ratingGiven: null,
    ),
    _PassengerRide(
      pickup: "I-8 Sector",
      dropOff: "Zero Point",
      date: "08 Apr",
      time: "21:15",
      status: _RideStatus.completed,
      fare: 320,
      driverName: "Bilal Ahmed",
      carInfo: "Suzuki · Black",
      ratingGiven: 4.7,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final completed = _rides.where((r) => r.status == _RideStatus.completed);
    final totalSpent = completed.fold<int>(0, (sum, r) => sum + r.fare);
    final totalTrips = completed.length;

    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(context),
            _summaryStrip(totalSpent: totalSpent, totalTrips: totalTrips),
            Expanded(
              child: _rides.isEmpty
                  ? const _EmptyState()
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 24.h),
                      itemCount: _rides.length,
                      itemBuilder: (_, i) => Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: _RideCard(ride: _rides[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 10.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 38.w,
              height: 38.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Consonants.whiteColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(Icons.arrow_back_rounded,
                  size: 18.sp, color: Consonants.boldTextColor),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomWidgets.customText(
                  "Ride History",
                  18.sp,
                  Consonants.boldTextColor,
                  FontWeight.w800,
                  maxLines: 1,
                ),
                SizedBox(height: 2.h),
                CustomWidgets.customText(
                  "All your past rides in one place",
                  10.sp,
                  Consonants.greyColor,
                  FontWeight.w500,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryStrip({
    required int totalSpent,
    required int totalTrips,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
        ),
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: Consonants.primaryColor.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryCell(
              icon: Icons.payments_rounded,
              label: "Total spent",
              value: "PKR $totalSpent",
            ),
          ),
          Container(
            width: 1,
            height: 32.h,
            color: Consonants.whiteColor.withValues(alpha: 0.30),
          ),
          Expanded(
            child: _summaryCell(
              icon: Icons.route_rounded,
              label: "Trips",
              value: "$totalTrips",
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCell({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18.sp, color: Consonants.whiteColor),
        SizedBox(width: 8.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomWidgets.customText(
              value,
              14.sp,
              Consonants.whiteColor,
              FontWeight.w800,
              maxLines: 1,
            ),
            SizedBox(height: 1.h),
            CustomWidgets.customText(
              label,
              9.sp,
              Consonants.whiteColor.withValues(alpha: 0.85),
              FontWeight.w500,
              maxLines: 1,
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ride card — only what a passenger actually needs at a glance.
// ─────────────────────────────────────────────────────────────────────────────

class _RideCard extends StatelessWidget {
  final _PassengerRide ride;
  const _RideCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    final isCompleted = ride.status == _RideStatus.completed;
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.circular(16.r),
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
          // ── Header: date · time + status pill ──
          Row(
            children: [
              Expanded(
                child: CustomWidgets.customText(
                  "${ride.date} · ${ride.time}",
                  11.sp,
                  Consonants.greyColor,
                  FontWeight.w600,
                  maxLines: 1,
                ),
              ),
              SizedBox(width: 8.w),
              _StatusPill(status: ride.status),
            ],
          ),
          SizedBox(height: 12.h),

          // ── Pickup / Drop-off timeline ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Timeline(),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _addressBlock("Pickup", ride.pickup),
                    SizedBox(height: 12.h),
                    _addressBlock("Drop-off", ride.dropOff),
                  ],
                ),
              ),
            ],
          ),

          if (isCompleted) ...[
            SizedBox(height: 12.h),
            Container(height: 1, color: Consonants.lightGreyColor),
            SizedBox(height: 10.h),
            // ── Footer: fare · driver/car · rating you gave ──
            Row(
              children: [
                Container(
                  width: 36.w,
                  height: 36.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Consonants.lightBlueColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_rounded,
                      size: 18.sp, color: Consonants.primaryColor),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomWidgets.customText(
                        ride.driverName,
                        12.sp,
                        Consonants.boldTextColor,
                        FontWeight.w700,
                        maxLines: 1,
                      ),
                      SizedBox(height: 2.h),
                      CustomWidgets.customText(
                        ride.carInfo,
                        10.sp,
                        Consonants.greyColor,
                        FontWeight.w500,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    CustomWidgets.customText(
                      "PKR ${ride.fare}",
                      13.sp,
                      Consonants.primaryColor,
                      FontWeight.w800,
                      maxLines: 1,
                    ),
                    if (ride.ratingGiven != null) ...[
                      SizedBox(height: 2.h),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded,
                              size: 12.sp,
                              color: const Color(0xffF5B800)),
                          SizedBox(width: 3.w),
                          CustomWidgets.customText(
                            ride.ratingGiven!.toStringAsFixed(1),
                            10.sp,
                            Consonants.greyColor,
                            FontWeight.w700,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _addressBlock(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomWidgets.customText(
          label,
          9.sp,
          Consonants.greyColor,
          FontWeight.w700,
          maxLines: 1,
        ),
        SizedBox(height: 2.h),
        CustomWidgets.customText(
          value,
          12.sp,
          Consonants.boldTextColor,
          FontWeight.w700,
          maxLines: 2,
        ),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 4.h),
        Container(
          width: 10.w,
          height: 10.w,
          decoration: BoxDecoration(
            color: Consonants.primaryColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: Consonants.lightBlueColor,
              width: 2,
            ),
          ),
        ),
        SizedBox(
          height: 28.h,
          child: VerticalDivider(
            thickness: 2.w,
            color: Consonants.lightGreyColor,
          ),
        ),
        Icon(Icons.location_on_rounded,
            size: 14.sp, color: const Color(0xffEF4444)),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final _RideStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final isCompleted = status == _RideStatus.completed;
    final bg = isCompleted
        ? Consonants.primaryGreenColor
        : const Color(0xffFEE2E2);
    final fg = isCompleted
        ? const Color(0xff15803D)
        : const Color(0xffEF4444);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: CustomWidgets.customText(
        isCompleted ? "Completed" : "Cancelled",
        10.sp,
        fg,
        FontWeight.w800,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84.w,
            height: 84.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Consonants.lightBlueColor,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.directions_car_filled_rounded,
                size: 36.sp, color: Consonants.primaryColor),
          ),
          SizedBox(height: 14.h),
          CustomWidgets.customText(
            "No rides yet",
            14.sp,
            Consonants.boldTextColor,
            FontWeight.w800,
          ),
          SizedBox(height: 4.h),
          CustomWidgets.customText(
            "Your past rides will show up here",
            11.sp,
            Consonants.greyColor,
            FontWeight.w500,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

enum _RideStatus { completed, cancelled }

class _PassengerRide {
  final String pickup;
  final String dropOff;
  final String date;
  final String time;
  final _RideStatus status;
  final int fare;
  final String driverName;
  final String carInfo;
  final double? ratingGiven;

  const _PassengerRide({
    required this.pickup,
    required this.dropOff,
    required this.date,
    required this.time,
    required this.status,
    required this.fare,
    required this.driverName,
    required this.carInfo,
    required this.ratingGiven,
  });
}
