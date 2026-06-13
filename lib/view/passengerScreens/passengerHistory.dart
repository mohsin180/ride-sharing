import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/passengerRideHistoryProvider.dart';
import 'package:ride_sharing/provider/providers.dart';
import 'package:ride_sharing/provider/rideStatsProvider.dart';
import 'package:ride_sharing/widgets/consonants/apiException.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
import 'package:ride_sharing/widgets/consonants/jwtUtils.dart';
import 'package:ride_sharing/widgets/consonants/tokenStorage.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';
import 'package:ride_sharing/widgets/custom/ratingSheet.dart';

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

class Passengerhistory extends ConsumerStatefulWidget {
  const Passengerhistory({super.key});

  @override
  ConsumerState<Passengerhistory> createState() => _PassengerhistoryState();
}

class _PassengerhistoryState extends ConsumerState<Passengerhistory> {
  /// Completed rides we've already auto-prompted to rate this session, so
  /// the post-trip sheet pops at most once per ride.
  final Set<String> _autoPrompted = {};
  bool _prompting = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(passengerRideHistoryProvider);
    final rides = async.value ?? const <PassengerRideHistoryItem>[];

    // After history loads, auto-open the rating sheet for the first
    // completed-but-unrated ride (post-trip prompt).
    _maybeAutoPrompt(rides);

    // Summary numbers run over completed rides only — cancelled trips
    // never charged the rider so they shouldn't inflate "Total spent".
    final completed = rides.where((r) => r.isCompleted);
    final totalSpent = completed.fold<double>(0, (sum, r) => sum + r.fare);
    final totalTrips = completed.length;

    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(context),
            _summaryStrip(totalSpent: totalSpent, totalTrips: totalTrips),
            Expanded(
              child: RefreshIndicator(
                color: Consonants.primaryColor,
                onRefresh: () async {
                  ref.invalidate(passengerRideHistoryProvider);
                  await ref.read(passengerRideHistoryProvider.future);
                },
                child: _buildBody(async, rides),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// State-aware list body. On the first fetch we show a spinner; once
  /// there's *any* cached data we keep rendering it and let the
  /// RefreshIndicator's spinner cover the loading signal instead.
  Widget _buildBody(
    AsyncValue<List<PassengerRideHistoryItem>> async,
    List<PassengerRideHistoryItem> rides,
  ) {
    if (async.isLoading && rides.isEmpty) return const _LoadingState();
    if (async.hasError && rides.isEmpty) {
      return _ErrorState(message: ErrorHandler.message(async.error));
    }
    if (rides.isEmpty) {
      // Empty must still be scrollable so RefreshIndicator can trigger.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: const [_EmptyState()],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 24.h),
      itemCount: rides.length,
      itemBuilder: (_, i) => Padding(
        padding: EdgeInsets.only(bottom: 12.h),
        child: _RideCard(
          ride: rides[i],
          onRate: () => _rateDriver(rides[i]),
        ),
      ),
    );
  }

  /// Auto-open the rating sheet once for the first completed ride that
  /// hasn't been rated yet — the passenger-side "post-trip" prompt.
  void _maybeAutoPrompt(List<PassengerRideHistoryItem> rides) {
    if (_prompting) return;
    PassengerRideHistoryItem? target;
    for (final r in rides) {
      if (r.isCompleted &&
          r.ratingGiven == null &&
          !_autoPrompted.contains(r.id)) {
        target = r;
        break;
      }
    }
    if (target == null) return;
    final ride = target;
    _autoPrompted.add(ride.id);
    _prompting = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) await _rateDriver(ride);
      _prompting = false;
    });
  }

  /// Rate a completed trip — the driver first, then each co-passenger you
  /// shared the ride with. Opens the star sheets in sequence; submits each
  /// and refreshes history + stats so the prompt doesn't recur.
  Future<void> _rateDriver(PassengerRideHistoryItem ride) async {
    // 1) Rate the driver.
    final hasName = ride.driverName?.trim().isNotEmpty ?? false;
    final name = hasName ? ride.driverName!.trim() : "your driver";
    final stars = await showRatingSheet(
      context: context,
      title: hasName ? "Rate $name" : "Rate your driver",
      subtitle: "How was your trip?",
      avatarInitial: hasName ? name[0].toUpperCase() : null,
    );
    if (stars != null) {
      try {
        await ref.read(rideServiceProvider).rateDriver(ride.id, stars);
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(CustomWidgets.customErrorSnackBar(e.message));
        }
      } catch (_) {
        // Already rated / failed — fall through to co-passengers.
      }
    }

    // 2) Rate the co-passengers you rode with.
    if (mounted) await _rateCoPassengers(ride.id);

    ref.invalidate(passengerRideHistoryProvider);
    ref.invalidate(rideStatsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          CustomWidgets.customSuccessSnackBar("Thanks for rating!"),
        );
    }
  }

  /// Walk the rider through rating the host + each co-passenger of a trip.
  /// Best-effort: skipping or a failed/duplicate submit just moves on.
  Future<void> _rateCoPassengers(String rideId) async {
    final RideDetails details;
    try {
      details = await ref.read(rideServiceProvider).getRideDetails(rideId);
    } catch (_) {
      return; // couldn't load the co-passenger list
    }
    if (!mounted) return;

    final myId = JwtUtils.extractUserId(await Tokenstorage.getToken() ?? '');
    // coPassengers already excludes you + the host; add the host unless it's you.
    final people = <({String id, String name})>[
      if (details.host.id.isNotEmpty && details.host.id != myId)
        (id: details.host.id, name: details.host.name),
      ...details.coPassengers.map((c) => (id: c.id, name: c.name)),
    ];
    for (final p in people) {
      if (!mounted) break;
      if (p.id.isEmpty) continue;
      final name = p.name.trim().isEmpty ? 'co-passenger' : p.name.trim();
      final stars = await showRatingSheet(
        context: context,
        title: 'Rate $name',
        subtitle: 'How was riding with them?',
        avatarInitial: name[0].toUpperCase(),
      );
      if (stars == null) continue;
      try {
        await ref.read(rideServiceProvider).rateCoPassenger(rideId, p.id, stars);
      } catch (_) {
        // Already rated / failed — keep going to the next person.
      }
    }
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
    required double totalSpent,
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
              value: "PKR ${totalSpent.round()}",
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
  final PassengerRideHistoryItem ride;
  final VoidCallback? onRate;
  const _RideCard({required this.ride, this.onRate});

  @override
  Widget build(BuildContext context) {
    final isCompleted = ride.isCompleted;
    // Offer to rate a completed ride that hasn't been rated yet.
    final canRate = isCompleted && ride.ratingGiven == null;
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
                  "${ride.dateLabel} · ${ride.timeLabel}",
                  11.sp,
                  Consonants.greyColor,
                  FontWeight.w600,
                  maxLines: 1,
                ),
              ),
              SizedBox(width: 8.w),
              _StatusPill(isCompleted: isCompleted),
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
                    _addressBlock("Drop-off", ride.drop),
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
                        (ride.driverName?.isNotEmpty ?? false)
                            ? ride.driverName!
                            : "Driver",
                        12.sp,
                        Consonants.boldTextColor,
                        FontWeight.w700,
                        maxLines: 1,
                      ),
                      SizedBox(height: 2.h),
                      CustomWidgets.customText(
                        (ride.carInfo?.isNotEmpty ?? false)
                            ? ride.carInfo!
                            : "—",
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
                      "PKR ${ride.fare.round()}",
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
            if (canRate && onRate != null) ...[
              SizedBox(height: 12.h),
              _rateButton(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _rateButton() {
    return GestureDetector(
      onTap: onRate,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 11.h),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Consonants.lightBlueColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: Consonants.primaryColor.withValues(alpha: 0.30),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded,
                size: 15.sp, color: const Color(0xffF5B800)),
            SizedBox(width: 6.w),
            CustomWidgets.customText(
              "Rate your driver",
              12.sp,
              Consonants.primaryColor,
              FontWeight.w800,
            ),
          ],
        ),
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
  final bool isCompleted;
  const _StatusPill({required this.isCompleted});

  @override
  Widget build(BuildContext context) {
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

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: 80.h),
        Center(
          child: SizedBox(
            width: 32.w,
            height: 32.w,
            child: const CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Consonants.primaryColor,
            ),
          ),
        ),
        SizedBox(height: 14.h),
        Center(
          child: CustomWidgets.customText(
            "Loading your rides…",
            12.sp,
            Consonants.greyColor,
            FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 80.h),
      children: [
        Center(
          child: Container(
            width: 64.w,
            height: 64.w,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xffFEE2E2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cloud_off_rounded,
              size: 28.sp,
              color: const Color(0xffEF4444),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        CustomWidgets.customText(
          "Couldn't load your rides",
          13.sp,
          Consonants.boldTextColor,
          FontWeight.w700,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 4.h),
        CustomWidgets.customText(
          message,
          11.sp,
          Consonants.greyColor,
          FontWeight.w500,
          textAlign: TextAlign.center,
          maxLines: 3,
        ),
        SizedBox(height: 8.h),
        CustomWidgets.customText(
          "Pull down to retry",
          10.sp,
          Consonants.greyColor,
          FontWeight.w500,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 80.h),
      child: Center(
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
      ),
    );
  }
}
