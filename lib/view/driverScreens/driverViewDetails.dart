import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/driverFeedProvider.dart';
import 'package:ride_sharing/provider/providers.dart';
import 'package:ride_sharing/widgets/consonants/apiException.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// Review screen for a ride request the driver opened from the feed.
/// Shows the host + route + fare, with a sticky CTA to Accept. Accepting
/// claims the ride (PENDING → ACCEPTED) and returns to the feed; the
/// in-trip pickup/drop management then lives in the "Your Ride" tab,
/// backed by `GET /api/v1/rides/driver/active`.

enum PickupStatus { upcoming, current, picked, dropped }

class Passenger {
  /// The rider's backend userId — used to mark them picked up / dropped off
  /// and to call them. Empty for the feed-review view (no ids needed there).
  final String userId;
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

  /// Contact number, so the driver can call to coordinate pickup. Null when
  /// unavailable (e.g. the feed-review view, which has no phone).
  final String? phone;

  const Passenger({
    this.userId = '',
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
    this.phone,
  });

  Passenger copyWith({PickupStatus? status}) => Passenger(
        userId: userId,
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
        phone: phone,
      );
}

class DriverViewDetails extends ConsumerStatefulWidget {
  /// The ride request to review, carried over from the driver feed.
  final AvailableRide ride;

  const DriverViewDetails({super.key, required this.ride});

  @override
  ConsumerState<DriverViewDetails> createState() => _DriverViewDetailsState();
}

class _DriverViewDetailsState extends ConsumerState<DriverViewDetails> {
  static const _palette = [
    Color(0xff60A5FA), Color(0xffF472B6), Color(0xffFBBF24),
    Color(0xff34D399), Color(0xffA78BFA),
  ];

  late List<Passenger> _passengers;

  /// True while the accept request is in flight, so the CTA can disable
  /// itself and avoid a double-claim.
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    // Seed with the feed summary (host only) so the screen renders instantly,
    // then load the full ride — host + every co-passenger and their stops.
    final r = widget.ride;
    final name = r.hostName.trim().isEmpty ? "Passenger" : r.hostName.trim();
    _passengers = [
      Passenger(
        name: name,
        initial: name[0].toUpperCase(),
        avatarColor: _palette[0],
        rating: r.hostRating != null ? r.hostRating!.toStringAsFixed(1) : "—",
        pickup: r.pickup,
        drop: r.drop,
        distanceToPickup:
            r.distanceKm != null ? "${r.distanceKm!.toStringAsFixed(1)} km" : "—",
        etaToPickup: r.etaMinutes != null ? "${r.etaMinutes} min" : "—",
        fare: r.fareForRider != null ? "Rs ${r.fareForRider!.round()}" : "Rs —",
        seats: 1,
        status: PickupStatus.current,
        isHost: true,
      ),
    ];
    _loadFullRide();
  }

  /// Fetch the full ride so the driver sees the host AND every co-passenger,
  /// each with their own pickup/drop and a number to call.
  Future<void> _loadFullRide() async {
    try {
      final d = await ref.read(rideServiceProvider).getRideDetails(widget.ride.id);
      if (!mounted) return;
      // Weighted pricing: each rider's own share from the backend.
      String fareLabelFor(double? share) => share != null
          ? (d.fare?.format(share) ?? "Rs ${share.round()}")
          : (d.fare != null ? d.fare!.format(d.fare!.perRider) : "Rs —");
      String nameOr(String raw) =>
          raw.trim().isEmpty ? "Passenger" : raw.trim();

      final list = <Passenger>[];
      final hostName = nameOr(d.host.name);
      list.add(Passenger(
        userId: d.host.id,
        name: hostName,
        initial: hostName[0].toUpperCase(),
        avatarColor: _palette[0],
        rating: d.host.rating != null ? d.host.rating!.toStringAsFixed(1) : "—",
        pickup: d.pickup,
        drop: d.drop,
        distanceToPickup: widget.ride.distanceKm != null
            ? "${widget.ride.distanceKm!.toStringAsFixed(1)} km"
            : "—",
        etaToPickup:
            widget.ride.etaMinutes != null ? "${widget.ride.etaMinutes} min" : "—",
        fare: fareLabelFor(d.host.fareShare),
        seats: 1,
        status: PickupStatus.current,
        isHost: true,
        phone: d.host.phone,
      ));
      for (int i = 0; i < d.coPassengers.length; i++) {
        final c = d.coPassengers[i];
        final n = nameOr(c.name);
        list.add(Passenger(
          userId: c.id,
          name: n,
          initial: n[0].toUpperCase(),
          avatarColor: _palette[(i + 1) % _palette.length],
          rating: c.rating != null ? c.rating!.toStringAsFixed(1) : "—",
          pickup: c.pickup ?? d.pickup,
          drop: c.drop ?? d.drop,
          distanceToPickup: "—",
          etaToPickup: "—",
          fare: fareLabelFor(c.fareShare),
          seats: 1,
          status: PickupStatus.upcoming,
          phone: c.phone,
        ));
      }
      setState(() => _passengers = list);
    } catch (_) {
      // Keep the host-only summary on failure — the screen still works.
    }
  }

  /// Dial a number — opens the phone app with it pre-filled.
  Future<void> _callNumber(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.trim());
    try {
      if (await launchUrl(uri)) {
        return;
      }
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            CustomWidgets.customErrorSnackBar("Couldn't start the call"));
    }
  }

  /// Open the ride's pickup in the external maps app (directions to it).
  Future<void> _openPickupInMaps() async {
    final r = widget.ride;
    final uri = Uri.parse(
      "https://www.google.com/maps/dir/?api=1&destination=${r.pickupLat},${r.pickupLng}",
    );
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            CustomWidgets.customErrorSnackBar("Couldn't open maps"));
    }
  }

  Future<void> _offerToDrive() async {
    if (_accepting) return;
    setState(() => _accepting = true);
    try {
      await ref.read(rideServiceProvider).offerToDrive(widget.ride.id);
      // The offer is sent; the ride only becomes active once the host accepts
      // it (the driver gets a notification then). Refresh the feed but don't
      // claim it as the active trip yet.
      ref.invalidate(driverFeedProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          CustomWidgets.customSuccessSnackBar(
            "Offer sent — waiting for the host to accept",
          ),
        );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _accepting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(CustomWidgets.customErrorSnackBar(e.message));
      // Conflict / not-found means the ride is no longer available —
      // bounce back to a fresh feed.
      if (e.isConflict || e.isNotFound) {
        ref.invalidate(driverFeedProvider);
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _accepting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          CustomWidgets.customErrorSnackBar("Couldn't send offer"),
        );
    }
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
                  "${_passengers.length} ${_passengers.length == 1 ? 'rider' : 'riders'} in this trip",
                  10.sp,
                  Consonants.greyColor,
                  FontWeight.w500,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _openPickupInMaps,
            child: Container(
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
                if ((p.phone ?? '').trim().isNotEmpty) ...[
                  GestureDetector(
                    onTap: () => _callNumber(p.phone!),
                    child: Container(
                      width: 34.w,
                      height: 34.w,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Consonants.primaryGreenColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.call_rounded,
                          size: 16.sp, color: const Color(0xff15803D)),
                    ),
                  ),
                  SizedBox(width: 8.w),
                ],
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
                // Read-only review screen — fare on the left, no
                // per-passenger actions until the ride is accepted and
                // managed from the "Your Ride" tab.
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

  Widget _completeRideBar() {
    // Single CTA: offer to drive. The host must accept the offer before the
    // driver is assigned; while the request is in flight the bar greys out to
    // prevent a double-send, and on success the screen pops back to the feed.
    return _stickyBar(
      onTap: _accepting ? null : _offerToDrive,
      active: !_accepting,
      icon: Icons.local_taxi_rounded,
      label: _accepting ? "Sending offer…" : "Offer to drive",
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
