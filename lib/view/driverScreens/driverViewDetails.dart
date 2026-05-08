import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

/// Detailed view of an accepted ride — list of passengers in pickup
/// order, per-passenger status, quick actions and a sticky CTA to
/// complete the trip once all riders have been dropped off.

enum PickupStatus { upcoming, current, picked, dropped }

class Passenger {
  final String name;
  final String initial;
  final Color avatarColor;
  final String rating;
  final String pickup;
  final String drop;
  final String distanceToPickup;
  final String etaToPickup;
  final String fare;
  final int seats;
  final PickupStatus status;
  final bool isHost;

  const Passenger({
    required this.name,
    required this.initial,
    required this.avatarColor,
    required this.rating,
    required this.pickup,
    required this.drop,
    required this.distanceToPickup,
    required this.etaToPickup,
    required this.fare,
    required this.seats,
    required this.status,
    this.isHost = false,
  });

  Passenger copyWith({PickupStatus? status}) => Passenger(
        name: name,
        initial: initial,
        avatarColor: avatarColor,
        rating: rating,
        pickup: pickup,
        drop: drop,
        distanceToPickup: distanceToPickup,
        etaToPickup: etaToPickup,
        fare: fare,
        seats: seats,
        status: status ?? this.status,
        isHost: isHost,
      );
}

/// Demo seed data — first entry is the trip host (the passenger who
/// created the shared ride). Both [DriverViewDetails] and `driverRides`
/// derive their summary stats from this list so they stay in sync.
const List<Passenger> kSamplePassengers = [
  Passenger(
    name: "Sarah Ahmed",
    initial: "S",
    avatarColor: Color(0xffF472B6),
    rating: "4.9",
    pickup: "Hostel City, Block B",
    drop: "Taramri Chowk",
    distanceToPickup: "0.8 km",
    etaToPickup: "3 min",
    fare: "Rs 250",
    seats: 1,
    status: PickupStatus.current,
    isHost: true,
  ),
  Passenger(
    name: "Ayesha Khan",
    initial: "A",
    avatarColor: Color(0xff60A5FA),
    rating: "4.8",
    pickup: "Hostel City, Block A",
    drop: "Faizabad Metro",
    distanceToPickup: "0.0 km",
    etaToPickup: "On board",
    fare: "Rs 220",
    seats: 1,
    status: PickupStatus.upcoming,
  ),
  Passenger(
    name: "Hina Malik",
    initial: "H",
    avatarColor: Color(0xffFBBF24),
    rating: "4.7",
    pickup: "Bahria Phase 7",
    drop: "Faizabad Metro",
    distanceToPickup: "2.4 km",
    etaToPickup: "8 min",
    fare: "Rs 180",
    seats: 1,
    status: PickupStatus.upcoming,
  ),
];

class DriverViewDetails extends StatefulWidget {
  const DriverViewDetails({super.key});

  @override
  State<DriverViewDetails> createState() => _DriverViewDetailsState();
}

class _DriverViewDetailsState extends State<DriverViewDetails> {
  late List<Passenger> _passengers;

  /// Whether the driver has accepted this ride. While `false` the
  /// passenger cards are read-only (no call/message/status actions)
  /// and the bottom CTA reads "Accept Ride". Tapping accept flips
  /// this to `true` and reveals the management flow.
  bool _isAccepted = false;

  @override
  void initState() {
    super.initState();
    _passengers = List.of(kSamplePassengers);
  }

  void _acceptRide() {
    setState(() => _isAccepted = true);
    ScaffoldMessenger.of(context).showSnackBar(
      CustomWidgets.customSuccessSnackBar("Ride accepted"),
    );
  }

  void _advance(int index) {
    setState(() {
      final p = _passengers[index];
      PickupStatus? next;
      switch (p.status) {
        case PickupStatus.upcoming:
          next = PickupStatus.current;
          break;
        case PickupStatus.current:
          next = PickupStatus.picked;
          break;
        case PickupStatus.picked:
          next = PickupStatus.dropped;
          break;
        case PickupStatus.dropped:
          next = null;
          break;
      }
      if (next != null) _passengers[index] = p.copyWith(status: next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pickedUp = _passengers
        .where((p) =>
            p.status == PickupStatus.picked ||
            p.status == PickupStatus.dropped)
        .length;
    final fareSum = _passengers.fold<int>(0, (sum, p) {
      final digits = p.fare.replaceAll(RegExp(r'[^0-9]'), '');
      return sum + (int.tryParse(digits) ?? 0);
    });

    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(bottom: 110.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _topBar(),
              SizedBox(height: 12.h),
              _activeRideBanner(),
              SizedBox(height: 16.h),
              _summaryStrip(
                count: _passengers.length,
                pickedUp: pickedUp,
                fare: fareSum,
              ),
              SizedBox(height: 22.h),
              _sectionLabel("Pickup Order"),
              SizedBox(height: 10.h),
              for (int i = 0; i < _passengers.length; i++) ...[
                _passengerCard(_passengers[i], i),
                if (i != _passengers.length - 1) SizedBox(height: 12.h),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: _completeRideBar(),
    );
  }

  // ─── Top bar with back button + title ────────────────────
  Widget _topBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(14.w, 10.h, 20.w, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 40.w,
              height: 40.w,
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
              child: Icon(
                Icons.arrow_back_rounded,
                size: 18.sp,
                color: Consonants.boldTextColor,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomWidgets.customText(
                  "My Passengers",
                  17.sp,
                  Consonants.boldTextColor,
                  FontWeight.w800,
                ),
                SizedBox(height: 2.h),
                CustomWidgets.customText(
                  "${_passengers.length} riders in this trip",
                  10.sp,
                  Consonants.greyColor,
                  FontWeight.w500,
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Consonants.whiteColor,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.map_outlined,
                    size: 14.sp, color: Consonants.primaryColor),
                SizedBox(width: 5.w),
                CustomWidgets.customText(
                  "Map",
                  11.sp,
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

  // ─── Active ride banner (top hero strip) ─────────────────
  Widget _activeRideBanner() {
    final current = _passengers.firstWhere(
      (p) => p.status == PickupStatus.current,
      orElse: () => _passengers.firstWhere(
        (p) => p.status == PickupStatus.upcoming,
        orElse: () => _passengers.first,
      ),
    );
    final isHeading = current.status == PickupStatus.current;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
        ),
        boxShadow: [
          BoxShadow(
            color: Consonants.primaryColor.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8.w,
                height: 8.w,
                decoration: const BoxDecoration(
                  color: Consonants.whiteColor,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 6.w),
              CustomWidgets.customText(
                isHeading ? "Heading to next pickup" : "Active Ride",
                10.sp,
                Consonants.whiteColor.withValues(alpha: 0.90),
                FontWeight.w700,
              ),
              const Spacer(),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 11.sp, color: Consonants.whiteColor),
                    SizedBox(width: 3.w),
                    CustomWidgets.customText(
                      current.etaToPickup,
                      10.sp,
                      Consonants.whiteColor,
                      FontWeight.w800,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.40),
                    width: 2,
                  ),
                ),
                child: Text(
                  current.initial,
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
                    CustomWidgets.customText(
                      current.name,
                      14.sp,
                      Consonants.whiteColor,
                      FontWeight.w800,
                    ),
                    SizedBox(height: 2.h),
                    CustomWidgets.customText(
                      isHeading
                          ? "${current.distanceToPickup} away from pickup"
                          : "On the way to drop-off",
                      11.sp,
                      Consonants.whiteColor.withValues(alpha: 0.90),
                      FontWeight.w500,
                    ),
                  ],
                ),
              ),
              Container(
                width: 38.w,
                height: 38.w,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Consonants.whiteColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.navigation_rounded,
                    size: 18.sp, color: Consonants.primaryColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Summary strip ───────────────────────────────────────
  Widget _summaryStrip({
    required int count,
    required int pickedUp,
    required int fare,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        children: [
          Expanded(
            child: _summaryTile(
              icon: Icons.people_alt_rounded,
              value: "$count",
              label: "Riders",
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _summaryTile(
              icon: Icons.check_circle_rounded,
              value: "$pickedUp/$count",
              label: "Picked up",
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _summaryTile(
              icon: Icons.payments_rounded,
              value: "Rs $fare",
              label: "Total fare",
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryTile({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
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
          Container(
            width: 30.w,
            height: 30.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Consonants.lightBlueColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14.sp, color: Consonants.primaryColor),
          ),
          SizedBox(height: 6.h),
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

  // ─── Section label ───────────────────────────────────────
  Widget _sectionLabel(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Row(
        children: [
          CustomWidgets.customText(
            text.toUpperCase(),
            10.sp,
            Consonants.greyColor,
            FontWeight.w700,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Container(
              height: 1,
              color: Consonants.lightGreyColor,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Passenger card ──────────────────────────────────────
  Widget _passengerCard(Passenger p, int index) {
    final isCurrent = p.status == PickupStatus.current;
    final isFinished = p.status == PickupStatus.dropped;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.circular(20.r),
        border: isCurrent
            ? Border.all(
                color: Consonants.primaryColor.withValues(alpha: 0.40),
                width: 1.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: isCurrent
                ? Consonants.primaryColor.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: isCurrent ? 16 : 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 0),
            child: Row(
              children: [
                Container(
                  width: 26.w,
                  height: 26.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? Consonants.primaryColor
                        : Consonants.lightBlueColor,
                    shape: BoxShape.circle,
                  ),
                  child: CustomWidgets.customText(
                    "${index + 1}",
                    11.sp,
                    isCurrent
                        ? Consonants.whiteColor
                        : Consonants.primaryColor,
                    FontWeight.w800,
                  ),
                ),
                SizedBox(width: 10.w),
                Container(
                  width: 42.w,
                  height: 42.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.avatarColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: p.avatarColor.withValues(alpha: 0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    p.initial,
                    style: TextStyle(
                      color: Consonants.whiteColor,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      fontFamily: Consonants.fontFamily,
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: CustomWidgets.customText(
                              p.name,
                              13.sp,
                              Consonants.boldTextColor,
                              FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Icon(Icons.verified_rounded,
                              size: 12.sp,
                              color: Consonants.primaryColor),
                        ],
                      ),
                      SizedBox(height: 3.h),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              size: 11.sp,
                              color: const Color(0xffF5B800)),
                          SizedBox(width: 3.w),
                          CustomWidgets.customText(
                            p.rating,
                            10.sp,
                            Consonants.greyColor,
                            FontWeight.w600,
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
                            "${p.seats} seat",
                            10.sp,
                            Consonants.greyColor,
                            FontWeight.w500,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _statusPill(p.status),
              ],
            ),
          ),

          SizedBox(height: 14.h),

          if (p.status == PickupStatus.current ||
              p.status == PickupStatus.upcoming)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Consonants.lightBlueColor,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  children: [
                    Icon(Icons.near_me_rounded,
                        size: 14.sp, color: Consonants.primaryColor),
                    SizedBox(width: 6.w),
                    CustomWidgets.customText(
                      "Pickup is ${p.distanceToPickup} away",
                      11.sp,
                      Consonants.boldTextColor,
                      FontWeight.w700,
                    ),
                    const Spacer(),
                    Icon(Icons.access_time_rounded,
                        size: 12.sp, color: Consonants.primaryColor),
                    SizedBox(width: 4.w),
                    CustomWidgets.customText(
                      p.etaToPickup,
                      10.sp,
                      Consonants.primaryColor,
                      FontWeight.w800,
                    ),
                  ],
                ),
              ),
            ),

          if (p.status == PickupStatus.current ||
              p.status == PickupStatus.upcoming)
            SizedBox(height: 14.h),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            child: _routeTimeline(pickup: p.pickup, drop: p.drop),
          ),

          SizedBox(height: 14.h),

          Container(
            margin: EdgeInsets.symmetric(horizontal: 14.w),
            height: 1,
            color: Consonants.lightGreyColor,
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 14.h),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomWidgets.customText(
                      "Fare",
                      9.sp,
                      Consonants.greyColor,
                      FontWeight.w600,
                    ),
                    SizedBox(height: 1.h),
                    CustomWidgets.customText(
                      p.fare,
                      15.sp,
                      Consonants.primaryColor,
                      FontWeight.w800,
                    ),
                  ],
                ),
                const Spacer(),
                // Per-passenger actions only appear after the driver
                // has accepted the ride. Before that, the card is
                // read-only — fare on the left, blank on the right.
                if (_isAccepted) ...[
                  _circleAction(Icons.phone_rounded),
                  SizedBox(width: 8.w),
                  _circleAction(Icons.message_rounded),
                  SizedBox(width: 10.w),
                  _primaryActionButton(
                    status: p.status,
                    onTap: isFinished ? null : () => _advance(index),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Status pill ─────────────────────────────────────────
  Widget _statusPill(PickupStatus status) {
    late final String label;
    late final Color fg;
    late final Color bg;
    late final IconData icon;

    switch (status) {
      case PickupStatus.upcoming:
        label = "Upcoming";
        fg = Consonants.greyColor;
        bg = Consonants.lightGreyColor;
        icon = Icons.schedule_rounded;
        break;
      case PickupStatus.current:
        label = "Heading there";
        fg = Consonants.primaryColor;
        bg = Consonants.lightBlueColor;
        icon = Icons.directions_car_rounded;
        break;
      case PickupStatus.picked:
        label = "Picked up";
        fg = const Color(0xffB45309);
        bg = const Color(0xffFEF3C7);
        icon = Icons.event_seat_rounded;
        break;
      case PickupStatus.dropped:
        label = "Dropped off";
        fg = const Color(0xff16A34A);
        bg = Consonants.primaryGreenColor;
        icon = Icons.check_circle_rounded;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10.sp, color: fg),
          SizedBox(width: 3.w),
          CustomWidgets.customText(label, 9.sp, fg, FontWeight.w800),
        ],
      ),
    );
  }

  // ─── Route timeline (pickup → drop) ─────────────────────
  Widget _routeTimeline({required String pickup, required String drop}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 11.w,
              height: 11.w,
              decoration: BoxDecoration(
                color: Consonants.whiteColor,
                shape: BoxShape.circle,
                border: Border.all(
                    color: Consonants.primaryColor, width: 2.5),
              ),
            ),
            Container(
              width: 2.w,
              height: 22.h,
              color: Consonants.lightGreyColor,
            ),
            Icon(Icons.location_on_rounded,
                size: 13.sp, color: const Color(0xffEF4444)),
          ],
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomWidgets.customText(
                "Pickup",
                9.sp,
                Consonants.greyColor,
                FontWeight.w600,
              ),
              SizedBox(height: 1.h),
              CustomWidgets.customText(
                pickup,
                11.sp,
                Consonants.boldTextColor,
                FontWeight.w700,
              ),
              SizedBox(height: 10.h),
              CustomWidgets.customText(
                "Destination",
                9.sp,
                Consonants.greyColor,
                FontWeight.w600,
              ),
              SizedBox(height: 1.h),
              CustomWidgets.customText(
                drop,
                11.sp,
                Consonants.boldTextColor,
                FontWeight.w700,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _circleAction(IconData icon) {
    return Container(
      width: 36.w,
      height: 36.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Consonants.lightBlueColor,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 16.sp, color: Consonants.primaryColor),
    );
  }

  Widget _primaryActionButton({
    required PickupStatus status,
    required VoidCallback? onTap,
  }) {
    late final String label;
    switch (status) {
      case PickupStatus.upcoming:
        label = "Start";
        break;
      case PickupStatus.current:
        label = "Picked up";
        break;
      case PickupStatus.picked:
        label = "Drop off";
        break;
      case PickupStatus.dropped:
        label = "Done";
        break;
    }
    final disabled = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          gradient: disabled
              ? null
              : const LinearGradient(
                  colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
                ),
          color: disabled ? Consonants.lightGreyColor : null,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: disabled
              ? null
              : [
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
            CustomWidgets.customText(
              label,
              11.sp,
              disabled ? Consonants.greyColor : Consonants.whiteColor,
              FontWeight.w800,
            ),
            SizedBox(width: 4.w),
            Icon(
              Icons.arrow_forward_rounded,
              size: 13.sp,
              color: disabled ? Consonants.greyColor : Consonants.whiteColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _completeRideBar() {
    // Three states for the bottom bar:
    //   1. Not yet accepted   → big gradient "Accept Ride" CTA
    //   2. Accepted, in-flight → grey "Drop off all riders to finish"
    //   3. Accepted, all done  → gradient "Complete Trip" CTA
    if (!_isAccepted) {
      return _stickyBar(
        onTap: _acceptRide,
        active: true,
        icon: Icons.check_circle_rounded,
        label: "Accept Ride",
      );
    }

    final allDone =
        _passengers.every((p) => p.status == PickupStatus.dropped);

    return _stickyBar(
      onTap: allDone
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                CustomWidgets.customSuccessSnackBar("Trip completed"),
              );
            }
          : null,
      active: allDone,
      icon: allDone ? Icons.flag_circle_rounded : Icons.lock_rounded,
      label: allDone ? "Complete Trip" : "Drop off all riders to finish",
    );
  }

  /// Shared shell for the bottom CTA so the three states above don't
  /// duplicate layout code. `active` toggles gradient vs grey.
  Widget _stickyBar({
    required VoidCallback? onTap,
    required bool active,
    required IconData icon,
    required String label,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              height: 50.h,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: active
                    ? const LinearGradient(
                        colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
                      )
                    : null,
                color: active ? null : Consonants.lightGreyColor,
                borderRadius: BorderRadius.circular(14.r),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color:
                              Consonants.primaryColor.withValues(alpha: 0.30),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 16.sp,
                    color:
                        active ? Consonants.whiteColor : Consonants.greyColor,
                  ),
                  SizedBox(width: 8.w),
                  CustomWidgets.customText(
                    label,
                    13.sp,
                    active ? Consonants.whiteColor : Consonants.greyColor,
                    FontWeight.w800,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
