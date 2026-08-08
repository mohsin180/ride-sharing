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
import 'package:ride_sharing/widgets/custom/appComponents.dart';
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
      backgroundColor: Consonants.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppHeader(
              title: "Ride History",
              showBack: true,
            ),
            _summaryStrip(totalSpent: totalSpent, totalTrips: totalTrips),
            Expanded(
              child: RefreshIndicator(
                color: Consonants.indigo,
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
      padding: EdgeInsets.fromLTRB(
        Consonants.gutter.w,
        8.h,
        Consonants.gutter.w,
        32.h,
      ),
      itemCount: rides.length,
      itemBuilder: (_, i) => Column(
        children: [
          _RideCard(
            ride: rides[i],
            onRate: () => _rateDriver(rides[i]),
          ),
          if (i != rides.length - 1) const AppDivider(),
        ],
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

  /// The screen's one gradient surface: what these trips cost, in total.
  /// Money is the largest thing here, so it carries the display figure.
  Widget _summaryStrip({
    required double totalSpent,
    required int totalTrips,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Consonants.gutter.w,
        0,
        Consonants.gutter.w,
        20.h,
      ),
      child: HeroSurface(
        padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 22.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Total spent",
              style: AppText.caption(color: const Color(0xCCFFFFFF))
                  .copyWith(fontSize: 13.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              "PKR ${totalSpent.round()}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.figure(color: Consonants.surface)
                  .copyWith(fontSize: 34.sp),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                HeroChip(
                  label: totalTrips == 1 ? "1 trip" : "$totalTrips trips",
                  icon: Icons.route_outlined,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ride card — only what a passenger actually needs at a glance.
// ─────────────────────────────────────────────────────────────────────────────

/// One trip in the history list. A list row — divided by a 1px rule from
/// its neighbours, never wrapped in a card.
class _RideCard extends StatelessWidget {
  final PassengerRideHistoryItem ride;
  final VoidCallback? onRate;
  const _RideCard({required this.ride, this.onRate});

  @override
  Widget build(BuildContext context) {
    final isCompleted = ride.isCompleted;
    // Offer to rate a completed ride that hasn't been rated yet.
    final canRate = isCompleted && ride.ratingGiven == null;
    final driver = (ride.driverName?.trim().isNotEmpty ?? false)
        ? ride.driverName!.trim()
        : "Driver";

    return Padding(
      padding: EdgeInsets.symmetric(vertical: Consonants.rowVertical.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? Consonants.chipBg
                      : Consonants.dangerWash,
                ),
                child: Icon(
                  isCompleted
                      ? Icons.route_outlined
                      : Icons.close_rounded,
                  size: 20.sp,
                  color: isCompleted
                      ? Consonants.iconInk
                      : Consonants.danger,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ride.pickup,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.rowLabel().copyWith(fontSize: 16.sp),
                    ),
                    SizedBox(height: 3.h),
                    Row(
                      children: [
                        Icon(
                          Icons.south_east_rounded,
                          size: 13.sp,
                          color: Consonants.textMuted,
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            ride.drop,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption().copyWith(fontSize: 13.sp),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 5.h),
                    Text(
                      "${ride.dateLabel} · ${ride.timeLabel} · $driver",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption().copyWith(fontSize: 12.5.sp),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isCompleted ? "PKR ${ride.fare.round()}" : "—",
                    maxLines: 1,
                    style: AppText.amount().copyWith(fontSize: 16.5.sp),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    _statusLabel(isCompleted),
                    style: AppText.caption(
                      color: isCompleted
                          ? Consonants.textMuted
                          : Consonants.danger,
                    ).copyWith(fontSize: 12.sp),
                  ),
                  if (ride.ratingGiven != null) ...[
                    SizedBox(height: 5.h),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_outline_rounded,
                          size: 13.sp,
                          color: Consonants.iconInk,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          ride.ratingGiven!.toStringAsFixed(1),
                          style:
                              AppText.caption().copyWith(fontSize: 12.sp),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (isCompleted && (ride.carInfo?.isNotEmpty ?? false)) ...[
            SizedBox(height: 10.h),
            Padding(
              padding: EdgeInsets.only(left: 58.w),
              child: Text(
                ride.carInfo!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption().copyWith(fontSize: 12.5.sp),
              ),
            ),
          ],
          if (canRate && onRate != null) ...[
            SizedBox(height: 12.h),
            Padding(
              padding: EdgeInsets.only(left: 58.w),
              child: _rateButton(),
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(bool isCompleted) {
    if (!isCompleted) return "Cancelled";
    if (ride.paid == null) return "Completed";
    return ride.paid! ? "Paid" : "Unpaid";
  }

  Widget _rateButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: onRate,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 9.h),
          decoration: BoxDecoration(
            color: Consonants.indigoWash,
            borderRadius: BorderRadius.circular(Consonants.rPill.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star_outline_rounded,
                size: 15.sp,
                color: Consonants.indigo,
              ),
              SizedBox(width: 6.w),
              Text(
                "Rate your driver",
                style: AppText.navLabel(color: Consonants.indigo)
                    .copyWith(fontSize: 13.sp),
              ),
            ],
          ),
        ),
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
            width: 30.w,
            height: 30.w,
            child: const CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Consonants.indigo,
            ),
          ),
        ),
        SizedBox(height: 18.h),
        Center(
          child: Text(
            "Loading your rides…",
            style: AppText.caption().copyWith(fontSize: 13.sp),
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
      padding: EdgeInsets.symmetric(
        horizontal: Consonants.gutter.w,
        vertical: 70.h,
      ),
      children: [
        Center(
          child: Container(
            width: 68.w,
            height: 68.w,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Consonants.dangerWash,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cloud_off_outlined,
              size: 30.sp,
              color: Consonants.danger,
            ),
          ),
        ),
        SizedBox(height: 18.h),
        Text(
          "Couldn't load your rides",
          textAlign: TextAlign.center,
          style: AppText.sectionHeading().copyWith(fontSize: 17.sp),
        ),
        SizedBox(height: 8.h),
        Text(
          message,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: AppText.paragraph().copyWith(fontSize: 15.sp),
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
      padding: EdgeInsets.symmetric(vertical: 70.h),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84.w,
              height: 84.w,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Consonants.indigoWash,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.directions_car_outlined,
                size: 34.sp,
                color: Consonants.indigo,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              "No rides yet",
              style: AppText.sectionHeading().copyWith(fontSize: 18.sp),
            ),
          ],
        ),
      ),
    );
  }
}
