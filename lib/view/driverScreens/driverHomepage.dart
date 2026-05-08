import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/provider/driverStatusProvider.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

/// Driver-side home screen.
///
/// Drivers do NOT publish rides — passengers do. So the home screen is
/// built around the things a driver actually does: go online, watch
/// today's earnings, and accept incoming ride requests.
class DriverHomepage extends StatefulWidget {
  const DriverHomepage({super.key});

  @override
  State<DriverHomepage> createState() => _DriverHomepageState();
}

class _DriverHomepageState extends State<DriverHomepage>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      body: SafeArea(
        child: Consumer(
          builder: (context, ref, _) {
            final isOnline = ref.watch(driverOnlineProvider);
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(bottom: 28.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(),
                  SizedBox(height: 16.h),
                  _EarningsHero(shimmer: _shimmerController),
                  SizedBox(height: 14.h),
                  _OnlineToggleCard(
                    isOnline: isOnline,
                    pulse: _pulseController,
                    onToggle: () =>
                        ref.read(driverOnlineProvider.notifier).toggle(),
                  ),
                  SizedBox(height: 18.h),
                  _QuickStatsRow(),
                  SizedBox(height: 22.h),
                  _PerformanceCard(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER  — greeting + avatar + notification bell
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 0),
      child: Row(
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Consonants.primaryColor.withValues(alpha: 0.30),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Text(
              "A",
              style: TextStyle(
                fontFamily: Consonants.fontFamily,
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: Consonants.whiteColor,
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
                    CustomWidgets.customText(
                      "Good morning,",
                      11.sp,
                      Consonants.greyColor,
                      FontWeight.w500,
                    ),
                    SizedBox(width: 4.w),
                    CustomWidgets.customText(
                      "👋",
                      11.sp,
                      Consonants.greyColor,
                      FontWeight.w500,
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                CustomWidgets.customText(
                  "Ali Hamza",
                  16.sp,
                  Consonants.boldTextColor,
                  FontWeight.w800,
                ),
              ],
            ),
          ),
          _circleIconButton(
            icon: Icons.send_outlined,
            badge: true,
            onTap: () => context.push(Approutes.driverMessages),
          ),
          SizedBox(width: 8.w),
          _circleIconButton(
            icon: Icons.notifications_none_rounded,
            badge: true,
            onTap: () => context.push(Approutes.driverNotification),
          ),
        ],
      ),
    );
  }

  Widget _circleIconButton({
    required IconData icon,
    bool badge = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42.w,
            height: 42.w,
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
            child: Icon(icon, size: 20.sp, color: Consonants.boldTextColor),
          ),
          if (badge)
            Positioned(
              top: 6.h,
              right: 8.w,
              child: Container(
                width: 9.w,
                height: 9.w,
                decoration: BoxDecoration(
                  color: const Color(0xffEF4444),
                  shape: BoxShape.circle,
                  border: Border.all(color: Consonants.whiteColor, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EARNINGS HERO  — gradient card with today's earnings + soft shimmer accents
// ─────────────────────────────────────────────────────────────────────────────

class _EarningsHero extends StatelessWidget {
  final AnimationController shimmer;

  const _EarningsHero({required this.shimmer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: [
          BoxShadow(
            color: Consonants.primaryColor.withValues(alpha: 0.32),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22.r),
        child: Stack(
          children: [
            // Gradient base — matches the profile hero header for a
            // strong, vibrant blue (no pale third stop, no washing out).
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
                ),
              ),
            ),
            // Subtle decorative circles — kept very faint so they
            // don't lighten the card's overall appearance.
            Positioned(
              top: -30.h,
              right: -30.w,
              child: Container(
                width: 120.w,
                height: 120.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Positioned(
              bottom: -40.h,
              right: 30.w,
              child: Container(
                width: 80.w,
                height: 80.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),
            // Animated shimmer streak — narrower and more transparent
            // so it adds life without washing the card out.
            AnimatedBuilder(
              animation: shimmer,
              builder: (_, __) {
                return Positioned(
                  left: -80.w + (shimmer.value * 360.w),
                  top: 0,
                  bottom: 0,
                  child: Transform.rotate(
                    angle: -0.5,
                    child: Container(
                      width: 50.w,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.06),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Padding(
              padding: EdgeInsets.all(18.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 14.sp,
                        color: Consonants.boldTextColor.withValues(alpha: 0.75),
                      ),
                      SizedBox(width: 6.w),
                      CustomWidgets.customText(
                        "Today's Earnings",
                        11.sp,
                        Consonants.boldTextColor.withValues(alpha: 0.75),
                        FontWeight.w600,
                      ),
                      const Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.trending_up_rounded,
                              size: 11.sp,
                              color: Consonants.boldTextColor,
                            ),
                            SizedBox(width: 3.w),
                            CustomWidgets.customText(
                              "+18%",
                              10.sp,
                              Consonants.boldTextColor,
                              FontWeight.w800,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      CustomWidgets.customText(
                        "Rs",
                        16.sp,
                        Consonants.boldTextColor.withValues(alpha: 0.85),
                        FontWeight.w600,
                      ),
                      SizedBox(width: 6.w),
                      CustomWidgets.customText(
                        "1,240",
                        32.sp,
                        Consonants.boldTextColor,
                        FontWeight.w800,
                      ),
                      SizedBox(width: 6.w),
                      Padding(
                        padding: EdgeInsets.only(bottom: 6.h),
                        child: CustomWidgets.customText(
                          "/ Rs 2,000 goal",
                          10.sp,
                          Consonants.boldTextColor.withValues(alpha: 0.65),
                          FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  // Goal progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20.r),
                    child: Stack(
                      children: [
                        Container(
                          height: 8.h,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                        FractionallySizedBox(
                          widthFactor: 0.62,
                          child: Container(
                            height: 8.h,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20.r),
                              color: Consonants.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 14.h),
                  Row(
                    children: [
                      _heroStat(Icons.directions_car_filled_rounded, "8",
                          "Trips"),
                      SizedBox(width: 18.w),
                      _heroStat(Icons.access_time_rounded, "5h 20m",
                          "Online"),
                      
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroStat(IconData icon, String value, String label) {
    return Row(
      children: [
        Container(
          width: 28.w,
          height: 28.w,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(icon, size: 14.sp, color: Consonants.boldTextColor),
        ),
        SizedBox(width: 8.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomWidgets.customText(
              value,
              12.sp,
              Consonants.boldTextColor,
              FontWeight.w800,
            ),
            CustomWidgets.customText(
              label,
              9.sp,
              Consonants.boldTextColor.withValues(alpha: 0.70),
              FontWeight.w500,
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ONLINE / OFFLINE TOGGLE  — large, prominent, pulses while online
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
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isOnline
              ? Consonants.primaryColor.withValues(alpha: 0.30)
              : Consonants.lightGreyColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isOnline
                    ? Consonants.primaryColor
                    : Consonants.greyColor)
                .withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
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
                            width: 24.w + (pulse.value * 22.w),
                            height: 24.w + (pulse.value * 22.w),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Consonants.primaryColor.withValues(
                                alpha: 0.22 - (pulse.value * 0.18),
                              ),
                            ),
                          );
                        },
                      ),
                    Container(
                      width: 24.w,
                      height: 24.w,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnline
                            ? Consonants.primaryColor
                            : Consonants.lightGreyColor,
                      ),
                      child: Icon(
                        isOnline
                            ? Icons.bolt_rounded
                            : Icons.power_settings_new_rounded,
                        size: 14.sp,
                        color: isOnline
                            ? Consonants.whiteColor
                            : Consonants.greyColor,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomWidgets.customText(
                      isOnline ? "You're Online" : "You're Offline",
                      14.sp,
                      Consonants.boldTextColor,
                      FontWeight.w800,
                    ),
                    SizedBox(height: 2.h),
                    CustomWidgets.customText(
                      isOnline
                          ? "Receiving requests near Gulberg"
                          : "Tap to start receiving requests",
                      10.sp,
                      Consonants.greyColor,
                      FontWeight.w500,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 56.w,
                  height: 32.h,
                  padding: EdgeInsets.all(3.r),
                  alignment:
                      isOnline ? Alignment.centerRight : Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: isOnline
                        ? Consonants.primaryColor
                        : Consonants.lightGreyColor,
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: isOnline
                        ? [
                            BoxShadow(
                              color: Consonants.primaryColor
                                  .withValues(alpha: 0.40),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Container(
                    width: 26.w,
                    height: 26.h,
                    decoration: const BoxDecoration(
                      color: Consonants.whiteColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isOnline) ...[
            SizedBox(height: 12.h),
            Container(
              height: 1,
              color: Consonants.lightGreyColor,
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                _searchingDot(0),
                SizedBox(width: 4.w),
                _searchingDot(0.33),
                SizedBox(width: 4.w),
                _searchingDot(0.66),
                SizedBox(width: 10.w),
                CustomWidgets.customText(
                  "Searching for ride requests…",
                  11.sp,
                  Consonants.boldTextColor,
                  FontWeight.w600,
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
            color: Consonants.primaryColor.withValues(
              alpha: 0.30 + (t * 0.70),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK STATS  — three coloured tiles for at-a-glance stats
// ─────────────────────────────────────────────────────────────────────────────

class _QuickStatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        children: [
          Expanded(
            child: _statTile(
              icon: Icons.star_rounded,
              value: "4.9",
              label: "Rating",
              accent: const Color(0xffF59E0B),
              accentBg: const Color(0xffFEF3C7),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _statTile(
              icon: Icons.check_circle_rounded,
              value: "94%",
              label: "Acceptance",
              accent: Consonants.primaryColor,
              accentBg: Consonants.lightBlueColor,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _statTile(
              icon: Icons.route_rounded,
              value: "1,284",
              label: "Trips",
              accent: Consonants.primaryColor,
              accentBg: Consonants.lightBlueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile({
    required IconData icon,
    required String value,
    required String label,
    required Color accent,
    required Color accentBg,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 10.w),
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
          Container(
            width: 36.w,
            height: 36.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accentBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18.sp, color: accent),
          ),
          SizedBox(height: 8.h),
          CustomWidgets.customText(
            value,
            14.sp,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// PERFORMANCE CARD  — weekly mini bar chart of earnings
// ─────────────────────────────────────────────────────────────────────────────

class _PerformanceCard extends StatelessWidget {
  static const _bars = <_BarData>[
    _BarData("Mon", 0.55),
    _BarData("Tue", 0.40),
    _BarData("Wed", 0.72),
    _BarData("Thu", 0.48),
    _BarData("Fri", 0.86),
    _BarData("Sat", 1.00),
    _BarData("Sun", 0.62),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.circular(20.r),
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
                "This Week",
                14.sp,
                Consonants.boldTextColor,
                FontWeight.w800,
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: Consonants.primaryGreenColor,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Row(
                  children: [
                    Icon(Icons.trending_up_rounded,
                        size: 11.sp, color: const Color(0xff16A34A)),
                    SizedBox(width: 3.w),
                    CustomWidgets.customText(
                      "+24%",
                      10.sp,
                      const Color(0xff16A34A),
                      FontWeight.w800,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CustomWidgets.customText(
                "Rs 8,420",
                22.sp,
                Consonants.boldTextColor,
                FontWeight.w800,
              ),
              SizedBox(width: 6.w),
              Padding(
                padding: EdgeInsets.only(bottom: 4.h),
                child: CustomWidgets.customText(
                  "earned",
                  10.sp,
                  Consonants.greyColor,
                  FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 18.h),
          SizedBox(
            height: 100.h,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < _bars.length; i++) ...[
                  Expanded(child: _bar(_bars[i], highlighted: i == 5)),
                  if (i != _bars.length - 1) SizedBox(width: 8.w),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(_BarData data, {required bool highlighted}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: data.value,
              child: Container(
                decoration: BoxDecoration(
                  gradient: highlighted
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Consonants.primaryColor,
                            Color(0xff5AC8FA),
                          ],
                        )
                      : null,
                  color: highlighted ? null : Consonants.lightBlueColor,
                  borderRadius: BorderRadius.circular(8.r),
                  boxShadow: highlighted
                      ? [
                          BoxShadow(
                            color: Consonants.primaryColor
                                .withValues(alpha: 0.30),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 6.h),
        CustomWidgets.customText(
          data.label,
          9.sp,
          highlighted ? Consonants.primaryColor : Consonants.greyColor,
          highlighted ? FontWeight.w800 : FontWeight.w500,
        ),
      ],
    );
  }
}

class _BarData {
  final String label;
  final double value;

  const _BarData(this.label, this.value);
}
