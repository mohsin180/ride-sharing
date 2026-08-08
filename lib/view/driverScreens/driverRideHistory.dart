import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/driverRideHistoryProvider.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
import 'package:ride_sharing/widgets/custom/appComponents.dart';

/// Driver-side ride-history screen. Shows the driver's completed and
/// cancelled rides as a divided list, backed by
/// `GET /api/v1/rides/driver/history` via [driverHistoryProvider].
///
/// Each row surfaces only what the backend gives us per ride:
///   • Date + time (completedAt)
///   • Pickup and drop-off addresses
///   • Status (Completed / Cancelled)
///   • Earnings (fare) + passenger name
///
/// The driver DTO has no per-ride passenger count or rating-received, so
/// (unlike the passenger card) those are dropped.
///
/// Money earned is the loudest thing here: the total sits in the hero
/// panel, and each row's fare is the only coloured value on the line.
class DriverRideHistoryScreen extends ConsumerWidget {
  const DriverRideHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(driverHistoryProvider);
    final rides = async.value ?? const <DriverRideHistory>[];

    // Summary numbers run over completed rides only — cancelled trips
    // never earned anything so they shouldn't inflate "Total earned".
    final completed = rides.where((r) => r.isCompleted);
    final totalEarnings = completed.fold<double>(0, (sum, r) => sum + r.fare);
    final totalTrips = completed.length;

    return Scaffold(
      backgroundColor: Consonants.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppHeader(
              title: "Ride history",
              showBack: true,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
              child: _summaryHero(
                totalEarnings: totalEarnings,
                totalTrips: totalTrips,
              ),
            ),
            SizedBox(height: 8.h),
            Expanded(
              child: RefreshIndicator(
                color: Consonants.indigo,
                backgroundColor: Consonants.surface,
                onRefresh: () async {
                  ref.invalidate(driverHistoryProvider);
                  await ref.read(driverHistoryProvider.future);
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
    AsyncValue<List<DriverRideHistory>> async,
    List<DriverRideHistory> rides,
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
    // A history list divides with a rule — no card wrapper per row.
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(
          Consonants.gutter.w, 8.h, Consonants.gutter.w, 32.h),
      itemCount: rides.length,
      itemBuilder: (_, i) => Column(
        children: [
          _RideRow(ride: rides[i]),
          if (i != rides.length - 1) const AppDivider(),
        ],
      ),
    );
  }

  Widget _summaryHero({
    required double totalEarnings,
    required int totalTrips,
  }) {
    return HeroSurface(
      padding: EdgeInsets.fromLTRB(24.w, 22.h, 24.w, 22.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "TOTAL EARNED",
            style: AppText.navLabel(
              color: Consonants.surface.withValues(alpha: 0.72),
            ).copyWith(fontSize: 12.sp, letterSpacing: 0.8),
          ),
          SizedBox(height: 10.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                "Rs",
                style: AppText.amount(
                  color: Consonants.surface.withValues(alpha: 0.80),
                ).copyWith(fontSize: 16.sp),
              ),
              SizedBox(width: 8.w),
              Flexible(
                child: Text(
                  "${totalEarnings.round()}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.figure(color: Consonants.surface)
                      .copyWith(fontSize: 34.sp),
                ),
              ),
            ],
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ride row — one line per trip, separated by a rule.
// ─────────────────────────────────────────────────────────────────────────────

class _RideRow extends StatelessWidget {
  final DriverRideHistory ride;
  const _RideRow({required this.ride});

  @override
  Widget build(BuildContext context) {
    final isCompleted = ride.isCompleted;
    final pickup = ride.pickup.isEmpty ? "—" : ride.pickup;
    final drop = ride.drop.isEmpty ? "—" : ride.drop;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: Consonants.rowVertical.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  isCompleted ? Consonants.creditWash : Consonants.dangerWash,
            ),
            child: Icon(
              isCompleted
                  ? Icons.check_rounded
                  : Icons.close_rounded,
              size: 20.sp,
              color: isCompleted ? Consonants.credit : Consonants.danger,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ride.passengerName.isNotEmpty
                      ? ride.passengerName
                      : "Passenger",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.rowLabel().copyWith(fontSize: 16.sp),
                ),
                SizedBox(height: 4.h),
                Text(
                  "${ride.dateLabel} · ${ride.timeLabel}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption().copyWith(fontSize: 12.5.sp),
                ),
                SizedBox(height: 6.h),
                Text(
                  "$pickup → $drop",
                  maxLines: 2,
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
                isCompleted ? "Rs ${ride.fare.round()}" : "—",
                style: AppText.amount(
                  color: isCompleted
                      ? Consonants.credit
                      : Consonants.textMuted,
                ).copyWith(fontSize: 16.5.sp),
              ),
              SizedBox(height: 4.h),
              Text(
                isCompleted ? "Completed" : "Cancelled",
                style: AppText.caption(
                  color: isCompleted
                      ? Consonants.textMuted
                      : Consonants.danger,
                ).copyWith(fontSize: 12.sp),
              ),
            ],
          ),
        ],
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
        SizedBox(height: 90.h),
        Center(
          child: SizedBox(
            width: 30.w,
            height: 30.w,
            child: const CircularProgressIndicator(
              strokeWidth: 2.5,
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
          horizontal: Consonants.gutter.w, vertical: 80.h),
      children: [
        Center(
          child: Container(
            width: 84.w,
            height: 84.w,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Consonants.dangerWash,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cloud_off_outlined,
                size: 34.sp, color: Consonants.danger),
          ),
        ),
        SizedBox(height: 20.h),
        Text(
          "Couldn't load your rides",
          textAlign: TextAlign.center,
          style: AppText.sectionHeading().copyWith(fontSize: 18.sp),
        ),
        SizedBox(height: 8.h),
        Text(
          message,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: AppText.paragraph().copyWith(fontSize: 15.sp),
        ),
        SizedBox(height: 10.h),
        Text(
          "Pull down to retry",
          textAlign: TextAlign.center,
          style: AppText.caption().copyWith(fontSize: 12.5.sp),
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
      padding: EdgeInsets.symmetric(
          horizontal: Consonants.gutter.w, vertical: 80.h),
      child: Column(
        children: [
          Container(
            width: 84.w,
            height: 84.w,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Consonants.indigoWash,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.directions_car_outlined,
                size: 34.sp, color: Consonants.iconInk),
          ),
          SizedBox(height: 20.h),
          Text(
            "No rides yet",
            style: AppText.sectionHeading().copyWith(fontSize: 18.sp),
          ),
        ],
      ),
    );
  }
}
