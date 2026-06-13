import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/driverFeedProvider.dart';
import 'package:ride_sharing/provider/driverStatusProvider.dart';
import 'package:ride_sharing/view/driverScreens/driverViewDetails.dart';
import 'package:ride_sharing/widgets/consonants/apiException.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

/// Driver "Rides" tab — list of available shared-ride requests.
///
/// Drivers can filter by host gender (All / Male / Female) so they only
/// see requests from passengers they're comfortable picking up. Each
/// request is rendered as a summary card with the host info, route,
/// total fare, rider count, and CTAs to decline or view full details.
///
/// Backed by `driverFeedProvider` (GET /api/v1/rides/driver/feed) while
/// the driver is online; offline it shows a placeholder and skips the
/// fetch. Locally-declined ride ids are hidden until the next refresh.
class Driverrides extends ConsumerStatefulWidget {
  const Driverrides({super.key});

  @override
  ConsumerState<Driverrides> createState() => _DriverridesState();
}

enum _GenderFilter { all, male, female }

class _DriverridesState extends ConsumerState<Driverrides> {
  _GenderFilter _filter = _GenderFilter.all;

  // Ride ids the driver declined this session — hidden from the list
  // without a backend round-trip (there's no per-driver decline yet, so
  // a refresh brings them back).
  final Set<String> _declined = {};

  List<_RideRequest> _applyGenderFilter(List<_RideRequest> rides) {
    switch (_filter) {
      case _GenderFilter.all:
        return rides;
      case _GenderFilter.male:
        return rides.where((r) => r.gender == "MALE").toList();
      case _GenderFilter.female:
        return rides.where((r) => r.gender == "FEMALE").toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(driverOnlineProvider);

    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(driverFeedProvider),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.only(bottom: 24.h),
            child: !isOnline
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Header(rideCount: 0, isOnline: false),
                      SizedBox(height: 14.h),
                      _OfflinePlaceholder(
                        onGoOnline: () =>
                            ref.read(driverOnlineProvider.notifier).goOnline(),
                      ),
                    ],
                  )
                : ref.watch(driverFeedProvider).when(
                      loading: () => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _Header(rideCount: 0, isOnline: true),
                          SizedBox(height: 80.h),
                          const Center(child: CircularProgressIndicator()),
                        ],
                      ),
                      error: (e, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _Header(rideCount: 0, isOnline: true),
                          SizedBox(height: 14.h),
                          _FeedError(
                            message: e is ApiException
                                ? e.message
                                : "Couldn't load ride requests",
                            onRetry: () => ref.invalidate(driverFeedProvider),
                          ),
                        ],
                      ),
                      data: (rides) {
                        final all = rides
                            .where((r) => !_declined.contains(r.id))
                            .map(_RideRequest.fromAvailable)
                            .toList();
                        final filtered = _applyGenderFilter(all);
                        final maleCount =
                            all.where((r) => r.gender == "MALE").length;
                        final femaleCount =
                            all.where((r) => r.gender == "FEMALE").length;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Header(
                                rideCount: filtered.length, isOnline: true),
                            SizedBox(height: 14.h),
                            _FilterPills(
                              selected: _filter,
                              allCount: all.length,
                              maleCount: maleCount,
                              femaleCount: femaleCount,
                              onSelect: (v) => setState(() => _filter = v),
                            ),
                            SizedBox(height: 14.h),
                            if (filtered.isEmpty)
                              _EmptyState(filter: _filter)
                            else
                              for (int i = 0; i < filtered.length; i++) ...[
                                _RideSummaryCard(
                                  ride: filtered[i],
                                  onViewDetails: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DriverViewDetails(
                                        ride: filtered[i].source,
                                      ),
                                    ),
                                  ),
                                  onDecline: () {
                                    setState(
                                        () => _declined.add(filtered[i].id));
                                    ScaffoldMessenger.of(context)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(
                                        CustomWidgets.customErrorSnackBar(
                                            "Ride declined"),
                                      );
                                  },
                                ),
                                if (i != filtered.length - 1)
                                  SizedBox(height: 14.h),
                              ],
                          ],
                        );
                      },
                    ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FEED ERROR
// ─────────────────────────────────────────────────────────────────────────────

class _FeedError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _FeedError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.symmetric(vertical: 32.h, horizontal: 20.w),
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Consonants.lightGreyColor, width: 1.2),
      ),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 36.sp, color: Consonants.greyColor),
          SizedBox(height: 12.h),
          CustomWidgets.customText(
            message,
            12.sp,
            Consonants.boldTextColor,
            FontWeight.w700,
            textAlign: TextAlign.center,
            maxLines: 3,
          ),
          SizedBox(height: 14.h),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 10.h),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
                ),
                borderRadius: BorderRadius.circular(40.r),
              ),
              child: CustomWidgets.customText(
                "Retry",
                12.sp,
                Consonants.whiteColor,
                FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int rideCount;
  final bool isOnline;
  const _Header({required this.rideCount, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final subtitle = !isOnline
        ? "You're offline — go online to see requests"
        : rideCount == 1
            ? "1 shared ride matches your filter"
            : "$rideCount shared rides match your filter";
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomWidgets.customText(
                  "Available Rides",
                  18.sp,
                  Consonants.boldTextColor,
                  FontWeight.w800,
                ),
                SizedBox(height: 2.h),
                CustomWidgets.customText(
                  subtitle,
                  11.sp,
                  Consonants.greyColor,
                  FontWeight.w500,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          // Live status pill — green when online, grey when offline.
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: isOnline
                  ? Consonants.primaryGreenColor
                  : Consonants.lightGreyColor,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6.w,
                  height: 6.w,
                  decoration: BoxDecoration(
                    color: isOnline
                        ? const Color(0xff16A34A)
                        : Consonants.greyColor,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 5.w),
                CustomWidgets.customText(
                  isOnline ? "Online" : "Offline",
                  10.sp,
                  isOnline
                      ? const Color(0xff16A34A)
                      : Consonants.greyColor,
                  FontWeight.w800,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OFFLINE PLACEHOLDER  — gates the rides list behind the home-page online toggle
// ─────────────────────────────────────────────────────────────────────────────

class _OfflinePlaceholder extends StatelessWidget {
  final VoidCallback onGoOnline;
  const _OfflinePlaceholder({required this.onGoOnline});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.fromLTRB(20.w, 28.h, 20.w, 22.h),
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 84.w,
            height: 84.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Consonants.primaryColor.withValues(alpha: 0.15),
                  const Color(0xff5AC8FA).withValues(alpha: 0.15),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.power_settings_new_rounded,
              size: 36.sp,
              color: Consonants.primaryColor,
            ),
          ),
          SizedBox(height: 14.h),
          CustomWidgets.customText(
            "You're currently offline",
            15.sp,
            Consonants.boldTextColor,
            FontWeight.w800,
          ),
          SizedBox(height: 6.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: CustomWidgets.customText(
              "Go online to start receiving ride requests from passengers nearby",
              11.sp,
              Consonants.greyColor,
              FontWeight.w500,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 18.h),
          GestureDetector(
            onTap: onGoOnline,
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 22.w, vertical: 12.h),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
                ),
                borderRadius: BorderRadius.circular(40.r),
                boxShadow: [
                  BoxShadow(
                    color: Consonants.primaryColor.withValues(alpha: 0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded,
                      size: 16.sp, color: Consonants.whiteColor),
                  SizedBox(width: 6.w),
                  CustomWidgets.customText(
                    "Go Online",
                    13.sp,
                    Consonants.whiteColor,
                    FontWeight.w800,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 8.h),
          CustomWidgets.customText(
            "You can also toggle from the Home tab",
            10.sp,
            Consonants.greyColor,
            FontWeight.w500,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER PILLS  — All / Male / Female
// ─────────────────────────────────────────────────────────────────────────────

class _FilterPills extends StatelessWidget {
  final _GenderFilter selected;
  final int allCount;
  final int maleCount;
  final int femaleCount;
  final ValueChanged<_GenderFilter> onSelect;

  const _FilterPills({
    required this.selected,
    required this.allCount,
    required this.maleCount,
    required this.femaleCount,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        children: [
          _pill(
            label: "All",
            count: allCount,
            value: _GenderFilter.all,
          ),
          SizedBox(width: 8.w),
          _pill(
            label: "Male",
            count: maleCount,
            value: _GenderFilter.male,
            icon: Icons.male_rounded,
            iconColor: Consonants.primaryColor,
          ),
          SizedBox(width: 8.w),
          _pill(
            label: "Female",
            count: femaleCount,
            value: _GenderFilter.female,
            icon: Icons.female_rounded,
            iconColor: const Color(0xffEC4899),
          ),
        ],
      ),
    );
  }

  Widget _pill({
    required String label,
    required int count,
    required _GenderFilter value,
    IconData? icon,
    Color? iconColor,
  }) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
                )
              : null,
          color: isSelected ? null : Consonants.whiteColor,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Consonants.primaryColor.withValues(alpha: 0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13.sp,
                color: isSelected ? Consonants.whiteColor : iconColor,
              ),
              SizedBox(width: 5.w),
            ],
            CustomWidgets.customText(
              label,
              11.sp,
              isSelected ? Consonants.whiteColor : Consonants.boldTextColor,
              FontWeight.w700,
            ),
            SizedBox(width: 6.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.30)
                    : Consonants.lightBlueColor,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: CustomWidgets.customText(
                "$count",
                9.sp,
                isSelected ? Consonants.whiteColor : Consonants.primaryColor,
                FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final _GenderFilter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final label = switch (filter) {
      _GenderFilter.male => "No male host rides right now",
      _GenderFilter.female => "No female host rides right now",
      _GenderFilter.all => "No rides available right now",
    };
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.symmetric(vertical: 32.h, horizontal: 20.w),
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: Consonants.lightGreyColor,
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 64.w,
            height: 64.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Consonants.lightBlueColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.tune_rounded,
              size: 28.sp,
              color: Consonants.primaryColor,
            ),
          ),
          SizedBox(height: 12.h),
          CustomWidgets.customText(
            label,
            13.sp,
            Consonants.boldTextColor,
            FontWeight.w700,
          ),
          SizedBox(height: 4.h),
          CustomWidgets.customText(
            "Try switching the filter to see more rides",
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
// RIDE SUMMARY CARD
// ─────────────────────────────────────────────────────────────────────────────

class _RideSummaryCard extends StatelessWidget {
  final _RideRequest ride;
  final VoidCallback onViewDetails;
  final VoidCallback onDecline;

  const _RideSummaryCard({
    required this.ride,
    required this.onViewDetails,
    required this.onDecline,
  });

  bool get _isFemale => ride.gender == "FEMALE";

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: [
          BoxShadow(
            color: Consonants.primaryColor.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _hostStrip(),
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 16.h),
            child: Column(
              children: [
                _statsPills(),
                SizedBox(height: 14.h),
                Container(height: 1, color: Consonants.lightGreyColor),
                SizedBox(height: 14.h),
                _routeTimeline(),
                SizedBox(height: 14.h),
                _distanceDurationStrip(),
                SizedBox(height: 16.h),
                _actionButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Host strip (gradient top section) ──────────────────
  Widget _hostStrip() {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Consonants.whiteColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.40),
                width: 2,
              ),
            ),
            child: Text(
              ride.hostInitial,
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
                    CustomWidgets.customText(
                      "Trip Host",
                      9.sp,
                      Consonants.whiteColor.withValues(alpha: 0.85),
                      FontWeight.w700,
                    ),
                    SizedBox(width: 6.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: CustomWidgets.customText(
                        "Created the ride",
                        8.sp,
                        Consonants.whiteColor,
                        FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Flexible(
                      child: CustomWidgets.customText(
                        ride.hostName,
                        14.sp,
                        Consonants.whiteColor,
                        FontWeight.w800,
                        maxLines: 1,
                      ),
                    ),
                    SizedBox(width: 5.w),
                    Icon(Icons.verified_rounded,
                        size: 14.sp, color: Consonants.whiteColor),
                  ],
                ),
                SizedBox(height: 3.h),
                Row(
                  children: [
                    Icon(Icons.star_rounded,
                        size: 12.sp, color: const Color(0xffFFD54F)),
                    SizedBox(width: 3.w),
                    CustomWidgets.customText(
                      ride.hostRating,
                      11.sp,
                      Consonants.whiteColor.withValues(alpha: 0.95),
                      FontWeight.w700,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: Consonants.whiteColor,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isFemale ? Icons.female_rounded : Icons.male_rounded,
                  size: 11.sp,
                  color: _isFemale
                      ? const Color(0xffEC4899)
                      : Consonants.primaryColor,
                ),
                SizedBox(width: 3.w),
                CustomWidgets.customText(
                  _isFemale ? "Female" : "Male",
                  9.sp,
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

  // ─── Stats: total fare / avg rating / riders ────────────
  Widget _statsPills() {
    return Row(
      children: [
        Expanded(
          child: _statTile(
            icon: Icons.payments_rounded,
            value: "Rs ${ride.totalFare}",
            label: "Total fare",
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _statTile(
            icon: Icons.star_rounded,
            value: ride.hostRating,
            label: "Avg rating",
            iconColor: const Color(0xffF5B800),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _statTile(
            icon: Icons.people_alt_rounded,
            value: "${ride.riderCount}",
            label: "Riders",
          ),
        ),
      ],
    );
  }

  Widget _statTile({
    required IconData icon,
    required String value,
    required String label,
    Color? iconColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 6.w),
      decoration: BoxDecoration(
        color: Consonants.lightBlueColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Icon(icon,
              size: 16.sp, color: iconColor ?? Consonants.primaryColor),
          SizedBox(height: 4.h),
          CustomWidgets.customText(
            value,
            12.sp,
            Consonants.boldTextColor,
            FontWeight.w800,
          ),
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

  // ─── Route timeline (start → destination) ───────────────
  Widget _routeTimeline() {
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
                border:
                    Border.all(color: Consonants.primaryColor, width: 2.5),
              ),
            ),
            Container(
              width: 2.w,
              height: 26.h,
              color: Consonants.lightGreyColor,
            ),
            Icon(Icons.location_on_rounded,
                size: 14.sp, color: const Color(0xffEF4444)),
          ],
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CustomWidgets.customText(
                    "First pickup",
                    9.sp,
                    Consonants.greyColor,
                    FontWeight.w600,
                  ),
                  SizedBox(width: 6.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 6.w, vertical: 1.5.h),
                    decoration: BoxDecoration(
                      color: Consonants.lightBlueColor,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: CustomWidgets.customText(
                      "START",
                      8.sp,
                      Consonants.primaryColor,
                      FontWeight.w800,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2.h),
              CustomWidgets.customText(
                ride.startPoint,
                12.sp,
                Consonants.boldTextColor,
                FontWeight.w700,
                maxLines: 2,
              ),
              SizedBox(height: 14.h),
              Row(
                children: [
                  CustomWidgets.customText(
                    "Final drop-off",
                    9.sp,
                    Consonants.greyColor,
                    FontWeight.w600,
                  ),
                  SizedBox(width: 6.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 6.w, vertical: 1.5.h),
                    decoration: BoxDecoration(
                      color: const Color(0xffFEE2E2),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: CustomWidgets.customText(
                      "END",
                      8.sp,
                      const Color(0xffEF4444),
                      FontWeight.w800,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2.h),
              CustomWidgets.customText(
                ride.endPoint,
                12.sp,
                Consonants.boldTextColor,
                FontWeight.w700,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Distance + duration strip ──────────────────────────
  Widget _distanceDurationStrip() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Consonants.lightBlueColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Icon(Icons.straighten_rounded,
              size: 14.sp, color: Consonants.primaryColor),
          SizedBox(width: 6.w),
          CustomWidgets.customText(
            ride.distance,
            11.sp,
            Consonants.boldTextColor,
            FontWeight.w800,
          ),
          SizedBox(width: 4.w),
          CustomWidgets.customText(
            "total distance",
            10.sp,
            Consonants.greyColor,
            FontWeight.w500,
          ),
          const Spacer(),
          Icon(Icons.access_time_rounded,
              size: 12.sp, color: Consonants.primaryColor),
          SizedBox(width: 4.w),
          CustomWidgets.customText(
            ride.duration,
            11.sp,
            Consonants.primaryColor,
            FontWeight.w800,
          ),
        ],
      ),
    );
  }

  // ─── Action buttons (Decline + View Details) ────────────
  Widget _actionButtons() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onDecline,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 13.h),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Consonants.whiteColor,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: Consonants.lightGreyColor,
                  width: 1.5,
                ),
              ),
              child: CustomWidgets.customText(
                "Decline",
                12.sp,
                Consonants.boldTextColor,
                FontWeight.w700,
              ),
            ),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: onViewDetails,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 13.h),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
                ),
                borderRadius: BorderRadius.circular(14.r),
                boxShadow: [
                  BoxShadow(
                    color: Consonants.primaryColor.withValues(alpha: 0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomWidgets.customText(
                    "View Details",
                    12.sp,
                    Consonants.whiteColor,
                    FontWeight.w800,
                  ),
                  SizedBox(width: 6.w),
                  Icon(Icons.arrow_forward_rounded,
                      size: 14.sp, color: Consonants.whiteColor),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

class _RideRequest {
  final String id;
  final String hostName;
  final String hostInitial;
  final String hostRating;
  final String gender; // "MALE" or "FEMALE"
  final int totalFare;
  final int riderCount;
  final String startPoint;
  final String endPoint;
  final String distance;
  final String duration;

  /// The backend ride this card was built from — handed to the details
  /// screen so it can seed its review + Accept flow without a refetch.
  final AvailableRide source;

  const _RideRequest({
    required this.id,
    required this.hostName,
    required this.hostInitial,
    required this.hostRating,
    required this.gender,
    required this.totalFare,
    required this.riderCount,
    required this.startPoint,
    required this.endPoint,
    required this.distance,
    required this.duration,
    required this.source,
  });

  /// View-model from a backend [AvailableRide]. distanceKm / etaMinutes
  /// come back null on the driver feed (no rider location), so those
  /// fields render as "—". seatsAvailable stands in for the rider count.
  factory _RideRequest.fromAvailable(AvailableRide r) {
    final name = r.hostName.trim();
    return _RideRequest(
      id: r.id,
      hostName: name.isEmpty ? "Passenger" : name,
      hostInitial: name.isEmpty ? "?" : name[0].toUpperCase(),
      hostRating: r.hostRatingLabel,
      gender: r.hostGender ?? "",
      totalFare: r.fareForRider != null ? r.fareForRider!.round() : 0,
      riderCount: r.seatsAvailable,
      startPoint: r.pickup,
      endPoint: r.drop,
      distance: r.distanceKm != null
          ? "${r.distanceKm!.toStringAsFixed(1)} km"
          : "—",
      duration: r.etaMinutes != null ? "${r.etaMinutes} min" : "—",
      source: r,
    );
  }
}
