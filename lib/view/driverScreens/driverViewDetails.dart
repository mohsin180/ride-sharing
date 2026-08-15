import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/driverFeedProvider.dart';
import 'package:ride_sharing/provider/providers.dart';
import 'package:ride_sharing/widgets/consonants/apiException.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/appComponents.dart';
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
  // Avatar fills stay inside the brand ramp — two hues, no rainbow.
  static const _palette = [
    Consonants.indigo, Consonants.violet, Consonants.indigoMid,
    Color(0xff6E4BC9), Color(0xff8A5BE0),
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
        // Driver-facing: the trip total they'll earn, not a rider's share.
        fare: r.tripFare != null ? "Rs ${r.tripFare!.round()}" : "Rs —",
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
      backgroundColor: Consonants.canvas,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(bottom: 120.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _topBar(),
              _fareHero(
                count: _passengers.length,
                pickedUp: pickedUp,
                fare: fareSum,
              ),
              SizedBox(height: 30.h),
              _sectionLabel("Pickup order"),
              SizedBox(height: 14.h),
              for (int i = 0; i < _passengers.length; i++) ...[
                _passengerCard(_passengers[i], i),
                if (i != _passengers.length - 1) SizedBox(height: 14.h),
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
    return AppHeader(
      title: "Ride request",
      subtitle:
          "${_passengers.length} ${_passengers.length == 1 ? 'rider' : 'riders'} in this trip",
      showBack: true,
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        AppIconButton(
          icon: Icons.map_outlined,
          onTap: _openPickupInMaps,
        ),
      ],
    );
  }

  // ─── Fare hero — what the driver takes home, largest on the screen ──
  Widget _fareHero({
    required int count,
    required int pickedUp,
    required int fare,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
      child: HeroSurface(
        padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 22.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "TOTAL FARE",
              style: AppText.navLabel(
                color: Consonants.surface.withValues(alpha: 0.72),
              ).copyWith(fontSize: 12.sp, letterSpacing: 0.8),
            ),
            SizedBox(height: 12.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  "Rs",
                  style: AppText.amount(
                    color: Consonants.surface.withValues(alpha: 0.80),
                  ).copyWith(fontSize: 17.sp),
                ),
                SizedBox(width: 8.w),
                Flexible(
                  child: Text(
                    "$fare",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.figure(color: Consonants.surface)
                        .copyWith(fontSize: 36.sp),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                HeroChip(
                  label: count == 1 ? "1 rider" : "$count riders",
                  icon: Icons.people_alt_outlined,
                ),
                HeroChip(
                  label: "$pickedUp/$count picked up",
                  icon: Icons.check_circle_outline_rounded,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Section label ───────────────────────────────────────
  Widget _sectionLabel(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
      child: AppSectionHeading(label: text),
    );
  }

  // ─── Passenger card ──────────────────────────────────────
  Widget _passengerCard(Passenger p, int index) {
    final isCurrent = p.status == PickupStatus.current;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
      child: AppCard(
        padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 18.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 26.w,
                  height: 26.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: isCurrent ? Consonants.actionGradient : null,
                    color: isCurrent ? null : Consonants.chipBg,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    "${index + 1}",
                    style: AppText.navLabel(
                      color: isCurrent
                          ? Consonants.surface
                          : Consonants.iconInk,
                    ).copyWith(fontSize: 12.sp),
                  ),
                ),
                SizedBox(width: 12.w),
                Container(
                  width: 44.w,
                  height: 44.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.avatarColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    p.initial,
                    style: AppText.amount(color: Consonants.surface)
                        .copyWith(fontSize: 17.sp),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.rowLabel().copyWith(fontSize: 16.sp),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        "${p.rating} · ${p.seats} ${p.seats == 1 ? 'seat' : 'seats'}"
                        "${p.isHost ? ' · Host' : ''}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            AppText.caption().copyWith(fontSize: 12.5.sp),
                      ),
                    ],
                  ),
                ),
                if ((p.phone ?? '').trim().isNotEmpty) ...[
                  SizedBox(width: 8.w),
                  GestureDetector(
                    onTap: () => _callNumber(p.phone!),
                    child: Container(
                      width: 38.w,
                      height: 38.w,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Consonants.chipBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.call_outlined,
                          size: 18.sp, color: Consonants.iconInk),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 14.h),
            Row(
              children: [
                _statusPill(p.status),
                if (p.status == PickupStatus.current ||
                    p.status == PickupStatus.upcoming) ...[
                  SizedBox(width: 8.w),
                  Flexible(
                    child: _metaPill(
                      Icons.near_me_outlined,
                      "${p.distanceToPickup} away · ${p.etaToPickup}",
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 18.h),
            _routeTimeline(pickup: p.pickup, drop: p.drop),
            SizedBox(height: 18.h),
            const AppDivider(),
            SizedBox(height: 14.h),
            // Read-only review screen — fare only, no per-passenger actions
            // until the ride is accepted and managed from "Your Ride".
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Their fare share",
                        style:
                            AppText.caption().copyWith(fontSize: 12.5.sp),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        p.fare,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            AppText.amount().copyWith(fontSize: 18.sp),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaPill(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: Consonants.canvas,
        borderRadius: BorderRadius.circular(Consonants.rPill.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.sp, color: Consonants.textMuted),
          SizedBox(width: 5.w),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.navLabel().copyWith(fontSize: 12.sp),
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
        fg = Consonants.textMuted;
        bg = Consonants.chipBg;
        icon = Icons.schedule_rounded;
        break;
      case PickupStatus.current:
        label = "Heading there";
        fg = Consonants.indigo;
        bg = Consonants.indigoWash;
        icon = Icons.directions_car_outlined;
        break;
      case PickupStatus.picked:
        label = "Picked up";
        fg = Consonants.indigo;
        bg = Consonants.indigoWash;
        icon = Icons.event_seat_outlined;
        break;
      case PickupStatus.dropped:
        label = "Dropped off";
        fg = Consonants.credit;
        bg = Consonants.creditWash;
        icon = Icons.check_circle_outline_rounded;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Consonants.rPill.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.sp, color: fg),
          SizedBox(width: 5.w),
          Text(
            label,
            style: AppText.navLabel(color: fg).copyWith(fontSize: 12.sp),
          ),
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
            SizedBox(height: 5.h),
            Container(
              width: 10.w,
              height: 10.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Consonants.indigo, width: 2.5),
              ),
            ),
            Container(
              width: 1.5,
              height: 30.h,
              color: Consonants.border,
            ),
            Icon(Icons.location_on_outlined,
                size: 14.sp, color: Consonants.iconInk),
          ],
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Pickup",
                style: AppText.caption().copyWith(fontSize: 12.sp),
              ),
              SizedBox(height: 2.h),
              Text(
                pickup,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.rowLabel().copyWith(fontSize: 14.5.sp),
              ),
              SizedBox(height: 12.h),
              Text(
                "Destination",
                style: AppText.caption().copyWith(fontSize: 12.sp),
              ),
              SizedBox(height: 2.h),
              Text(
                drop,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.rowLabel().copyWith(fontSize: 14.5.sp),
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
      icon: Icons.local_taxi_outlined,
      label: _accepting ? "Sending offer…" : "Offer to drive",
    );
  }

  /// The screen's primary action, pinned to the bottom over a translucent
  /// canvas + blur rather than an opaque bar.
  Widget _stickyBar({
    required VoidCallback? onTap,
    required IconData icon,
    required String label,
  }) {
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
              child: AppButton(
                label: label,
                icon: icon,
                isLoading: _accepting,
                onPressed: onTap,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
