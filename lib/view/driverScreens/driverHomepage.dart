import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/provider/driverEarningsProvider.dart';
import 'package:ride_sharing/provider/driverStatusProvider.dart';
import 'package:ride_sharing/provider/messagingProvider.dart';
import 'package:ride_sharing/provider/notificationProvider.dart';
import 'package:ride_sharing/provider/profileProvider.dart';
import 'package:ride_sharing/provider/rideStatsProvider.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/appComponents.dart';

/// Driver-side home screen.
///
/// Drivers do NOT publish rides — passengers do. So the home screen is
/// built around the things a driver actually does: go online, watch
/// today's earnings, and accept incoming ride requests.
///
/// Hierarchy: the earnings hero is the screen's single gradient surface and
/// carries the largest figure; the online switch sits directly beneath it as
/// the one control that changes the driver's day.
class DriverHomepage extends StatefulWidget {
  const DriverHomepage({super.key});

  @override
  State<DriverHomepage> createState() => _DriverHomepageState();
}

class _DriverHomepageState extends State<DriverHomepage>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final isOnline = ref.watch(driverOnlineProvider);
        return AppScreen(
          header: const _Header(),
          navClearance: true,
          children: [
            const _EarningsHero(),
            SizedBox(height: Consonants.gapTiles.h),
            _OnlineToggleCard(
              isOnline: isOnline,
              pulse: _pulseController,
              onToggle: () => ref.read(driverOnlineProvider.notifier).toggle(),
            ),
            SizedBox(height: 28.h),
            const AppSectionHeading(label: "Your numbers"),
            SizedBox(height: 14.h),
            const _QuickStatsRow(),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER  — greeting + avatar + message / notification actions
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Real driver identity from the cached profile (mirrors the passenger
    // homepage greeting). While the profile loads, fall back to a generic
    // greeting + "?" avatar so nothing flashes a hardcoded placeholder.
    final profileAsync = ref.watch(driverProfileProvider);
    final fullName = profileAsync.maybeWhen(
      data: (p) => p.fullName.trim(),
      orElse: () => '',
    );
    final displayName = fullName.isEmpty ? 'there' : fullName;
    final initial =
        fullName.isEmpty ? '?' : fullName.characters.first.toUpperCase();
    final greeting = _timeOfDayGreeting(DateTime.now().hour);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          Consonants.gutter.w, 16.h, Consonants.gutter.w, 18.h),
      child: Row(
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: Consonants.actionGradient,
            ),
            child: Text(
              initial,
              style: AppText.amount(color: Consonants.surface)
                  .copyWith(fontSize: 18.sp),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: AppText.caption().copyWith(fontSize: 13.sp),
                ),
                SizedBox(height: 3.h),
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.screenTitle().copyWith(fontSize: 21.sp),
                ),
              ],
            ),
          ),
          Consumer(
            builder: (context, ref, _) {
              final unread = ref.watch(unreadMessagesCountProvider).maybeWhen(
                    data: (c) => c,
                    orElse: () => 0,
                  );
              return AppIconButton(
                icon: Icons.chat_bubble_outline_rounded,
                badge: unread > 0 ? const _Pip() : null,
                onTap: () => context.push(Approutes.driverMessages),
              );
            },
          ),
          SizedBox(width: 8.w),
          Consumer(
            builder: (context, ref, _) {
              final unread = ref.watch(unreadCountProvider).maybeWhen(
                    data: (c) => c,
                    orElse: () => 0,
                  );
              return AppIconButton(
                icon: Icons.notifications_none_rounded,
                badge: unread > 0 ? const _Pip() : null,
                onTap: () => context.push(Approutes.driverNotification),
              );
            },
          ),
        ],
      ),
    );
  }

  /// "Good morning" / "afternoon" / "evening" based on the device clock —
  /// mirrors the passenger homepage greeting.
  String _timeOfDayGreeting(int hour) {
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

/// Unread marker on a header action — a violet dot ringed in canvas so it
/// reads against the chip fill.
class _Pip extends StatelessWidget {
  const _Pip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11.w,
      height: 11.w,
      decoration: BoxDecoration(
        color: Consonants.violet,
        shape: BoxShape.circle,
        border: Border.all(color: Consonants.canvas, width: 2),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EARNINGS HERO  — the screen's one gradient surface, carrying today's figure
// ─────────────────────────────────────────────────────────────────────────────

class _EarningsHero extends ConsumerWidget {
  const _EarningsHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Real earnings from GET /rides/driver/earnings. While loading we show
    // a subtle "…" placeholder rather than a hardcoded number; on error the
    // card degrades to dashes instead of blocking the dashboard.
    final earningsAsync = ref.watch(driverEarningsProvider);
    final earnings = earningsAsync.value;
    final loading = earningsAsync.isLoading && earnings == null;

    String fmt(double v) => _grouped(v.round());
    final todayValue =
        earnings != null ? fmt(earnings.todayEarnings) : (loading ? "…" : "—");
    final todayTrips =
        earnings != null ? "${earnings.todayTrips}" : (loading ? "…" : "—");
    final lifetimeLine = earnings != null
        ? "Lifetime · Rs ${fmt(earnings.totalEarnings)} · ${earnings.totalTrips} trips"
        : (loading ? "Lifetime · …" : "Lifetime · —");

    return HeroSurface(
      padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 22.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "TODAY'S EARNINGS",
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
                  todayValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.figure(color: Consonants.surface)
                      .copyWith(fontSize: 38.sp),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            lifetimeLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption(
              color: Consonants.surface.withValues(alpha: 0.72),
            ).copyWith(fontSize: 12.5.sp),
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              HeroChip(
                label: "$todayTrips trips today",
                icon: Icons.directions_car_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Thousands-grouped integer ("1,240") without pulling in package:intl.
  String _grouped(int value) {
    final s = value.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return value < 0 ? '-$buf' : buf.toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ONLINE / OFFLINE TOGGLE  — the one control that changes the driver's day
// ─────────────────────────────────────────────────────────────────────────────

class _OnlineToggleCard extends StatelessWidget {
  final bool isOnline;
  final AnimationController pulse;
  final VoidCallback onToggle;

  const _OnlineToggleCard({
    required this.isOnline,
    required this.pulse,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 18.h),
      child: Column(
        children: [
          Row(
            children: [
              // Pulsing status dot
              SizedBox(
                width: 46.w,
                height: 46.w,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isOnline)
                      AnimatedBuilder(
                        animation: pulse,
                        builder: (_, __) {
                          return Container(
                            width: 26.w + (pulse.value * 20.w),
                            height: 26.w + (pulse.value * 20.w),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Consonants.violet.withValues(
                                alpha: 0.22 - (pulse.value * 0.18),
                              ),
                            ),
                          );
                        },
                      ),
                    Container(
                      width: 30.w,
                      height: 30.w,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isOnline ? Consonants.actionGradient : null,
                        color: isOnline ? null : Consonants.chipBg,
                      ),
                      child: Icon(
                        isOnline
                            ? Icons.bolt_rounded
                            : Icons.power_settings_new_rounded,
                        size: 16.sp,
                        color: isOnline
                            ? Consonants.surface
                            : Consonants.iconInk,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Text(
                  isOnline ? "You're online" : "You're offline",
                  style: AppText.sectionHeading().copyWith(fontSize: 17.sp),
                ),
              ),
              SizedBox(width: 10.w),
              GestureDetector(
                onTap: onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 58.w,
                  height: 34.h,
                  padding: EdgeInsets.all(3.r),
                  alignment:
                      isOnline ? Alignment.centerRight : Alignment.centerLeft,
                  decoration: BoxDecoration(
                    gradient: isOnline ? Consonants.actionGradient : null,
                    color: isOnline ? null : Consonants.chipBg,
                    borderRadius: BorderRadius.circular(Consonants.rPill.r),
                  ),
                  child: Container(
                    width: 28.w,
                    height: 28.h,
                    decoration: const BoxDecoration(
                      color: Consonants.surface,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isOnline) ...[
            SizedBox(height: 16.h),
            const AppDivider(),
            SizedBox(height: 16.h),
            Row(
              children: [
                _searchingDot(0),
                SizedBox(width: 5.w),
                _searchingDot(0.33),
                SizedBox(width: 5.w),
                _searchingDot(0.66),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    "Searching for ride requests…",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.rowLabel(color: Consonants.textMuted)
                        .copyWith(fontSize: 14.sp),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _searchingDot(double phase) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) {
        final t = (pulse.value + phase) % 1.0;
        return Container(
          width: 6.w,
          height: 6.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Consonants.violet.withValues(alpha: 0.30 + (t * 0.70)),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK STATS  — two white tiles for at-a-glance numbers
// ─────────────────────────────────────────────────────────────────────────────

class _QuickStatsRow extends ConsumerWidget {
  const _QuickStatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rating + Trips come from the real backend stats (GET /rides/stats,
    // role-aware). The "Acceptance %" tile was removed — there's no backend
    // source for it yet, so we don't fake it.
    final stats = ref.watch(rideStatsProvider);
    final rating = stats.maybeWhen(
      data: (s) => s.ratingLabel,
      orElse: () => "—",
    );
    final trips = stats.maybeWhen(
      data: (s) => "${s.trips}",
      orElse: () => "—",
    );

    return Row(
      children: [
        Expanded(
          child: _statTile(
            icon: Icons.star_outline_rounded,
            value: rating,
            label: "Rating",
          ),
        ),
        SizedBox(width: Consonants.gapTiles.w),
        Expanded(
          child: _statTile(
            icon: Icons.route_outlined,
            value: trips,
            label: "Trips",
          ),
        ),
      ],
    );
  }

  Widget _statTile({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return AppCard(
      padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Consonants.indigoWash,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20.sp, color: Consonants.iconInk),
          ),
          SizedBox(height: 14.h),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.screenTitle().copyWith(fontSize: 22.sp),
          ),
          SizedBox(height: 3.h),
          Text(label, style: AppText.caption().copyWith(fontSize: 12.5.sp)),
        ],
      ),
    );
  }
}
