import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/model/rideModels.dart';
import 'package:ride_sharing/provider/driverFeedProvider.dart';
import 'package:ride_sharing/provider/providers.dart';
import 'package:ride_sharing/provider/driverStatusProvider.dart';
import 'package:ride_sharing/view/driverScreens/driverViewDetails.dart';
import 'package:ride_sharing/view/nearbyRidesMap.dart';
import 'package:ride_sharing/widgets/consonants/apiException.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/appComponents.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

/// Driver "Rides" tab — list of available shared-ride requests.
///
/// Each request is rendered as a summary card with the host info, route,
/// total fare, rider count, and CTAs to decline or view full details.
/// The list is ordered nearest-first.
///
/// Backed by `driverFeedProvider` (GET /api/v1/rides/driver/feed) while
/// the driver is online; offline it shows a placeholder and skips the
/// fetch. Locally-declined ride ids are hidden until the next refresh.
class Driverrides extends ConsumerStatefulWidget {
  const Driverrides({super.key});

  @override
  ConsumerState<Driverrides> createState() => _DriverridesState();
}

class _DriverridesState extends ConsumerState<Driverrides> {
  // Ride ids the driver declined this session — hidden from the list
  // without a backend round-trip (there's no per-driver decline yet, so
  // a refresh brings them back).
  final Set<String> _declined = {};

  /// Nearest first — the feed arrives in no particular order, and the
  /// closest pickup is the one a driver can actually act on.
  List<_RideRequest> _byDistance(List<_RideRequest> rides) {
    final list = [...rides];
    list.sort(
      (a, b) =>
          (a.source.distanceKm ?? 1e9).compareTo(b.source.distanceKm ?? 1e9),
    );
    return list;
  }

  /// Opens the nearby-requests map; tapping a pin opens that ride's details.
  Widget _mapButton(List<_RideRequest> rides) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NearbyRidesMapScreen(
            rides: rides.map((r) => r.source).toList(),
            title: 'Nearby requests',
            onTapRide: (ride) => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => DriverViewDetails(ride: ride)),
            ),
          ),
        ),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Consonants.chipBg,
          borderRadius: BorderRadius.circular(Consonants.rPill.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 16.sp, color: Consonants.iconInk),
            SizedBox(width: 6.w),
            Text(
              'Map',
              style: AppText.navLabel(
                color: Consonants.iconInk,
              ).copyWith(fontSize: 13.sp),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(driverOnlineProvider);

    return Scaffold(
      backgroundColor: Consonants.canvas,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: Consonants.indigo,
          backgroundColor: Consonants.surface,
          onRefresh: () async => ref.invalidate(driverFeedProvider),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.only(bottom: Consonants.navClearance.h),
            child: !isOnline
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Header(isOnline: false),
                      _OfflinePlaceholder(
                        onGoOnline: () =>
                            ref.read(driverOnlineProvider.notifier).goOnline(),
                      ),
                    ],
                  )
                : ref
                      .watch(driverFeedProvider)
                      .when(
                        // Don't flash the spinner on the 12s background poll.
                        skipLoadingOnReload: true,
                        loading: () => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _Header(isOnline: true),
                            SizedBox(height: 90.h),
                            const Center(
                              child: CircularProgressIndicator(
                                color: Consonants.indigo,
                                strokeWidth: 2.5,
                              ),
                            ),
                          ],
                        ),
                        error: (e, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _Header(isOnline: true),
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
                          final filtered = _byDistance(all);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _Header(isOnline: true),
                              // Nothing to pin — the map would open empty and
                              // fall back to its default centre, which reads
                              // as broken.
                              if (filtered.isNotEmpty) ...[
                                Row(
                                  children: [
                                    const Spacer(),
                                    _mapButton(filtered),
                                    SizedBox(width: Consonants.gutter.w),
                                  ],
                                ),
                              ],
                              SizedBox(height: 20.h),
                              if (filtered.isEmpty)
                                const _EmptyState()
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
                                      final id = filtered[i].id;
                                      // Hide it instantly, and persist the
                                      // decline so it stays gone on later polls.
                                      setState(() => _declined.add(id));
                                      ref
                                          .read(rideServiceProvider)
                                          .driverDeclineRide(id)
                                          .catchError((_) {});
                                      ScaffoldMessenger.of(context)
                                        ..hideCurrentSnackBar()
                                        ..showSnackBar(
                                          CustomWidgets.customErrorSnackBar(
                                            "Ride declined",
                                          ),
                                        );
                                    },
                                  ),
                                  if (i != filtered.length - 1)
                                    SizedBox(height: 16.h),
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
    // Full width so the centred column doesn't hug the left edge inside the
    // start-aligned parent Column.
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Consonants.gutter.w,
          40.h,
          Consonants.gutter.w,
          0,
        ),
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
              child: Icon(
                Icons.cloud_off_outlined,
                size: 34.sp,
                color: Consonants.iconInk,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppText.sectionHeading().copyWith(fontSize: 18.sp),
            ),
            SizedBox(height: 24.h),
            AppButton(
              label: "Try again",
              kind: AppButtonKind.secondary,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool isOnline;
  const _Header({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Consonants.gutter.w,
        18.h,
        Consonants.gutter.w,
        20.h,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              "Ride requests",
              style: AppText.screenTitle().copyWith(fontSize: 26.sp),
            ),
          ),
          SizedBox(width: 12.w),
          // Live status pill — indigo while online, muted when offline.
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
            decoration: BoxDecoration(
              color: isOnline ? Consonants.indigoWash : Consonants.chipBg,
              borderRadius: BorderRadius.circular(Consonants.rPill.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7.w,
                  height: 7.w,
                  decoration: BoxDecoration(
                    color: isOnline ? Consonants.violet : Consonants.textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 6.w),
                Text(
                  isOnline ? "Online" : "Offline",
                  style: AppText.navLabel(
                    color: isOnline ? Consonants.indigo : Consonants.textMuted,
                  ).copyWith(fontSize: 12.sp),
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
// OFFLINE PLACEHOLDER  — gates the rides list behind the online toggle
// ─────────────────────────────────────────────────────────────────────────────

class _OfflinePlaceholder extends StatelessWidget {
  final VoidCallback onGoOnline;
  const _OfflinePlaceholder({required this.onGoOnline});

  @override
  Widget build(BuildContext context) {
    // Full width so the stretched column fills the screen rather than
    // shrink-wrapping inside the start-aligned parent Column.
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HeroSurface(
              padding: EdgeInsets.fromLTRB(24.w, 26.h, 24.w, 26.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52.w,
                    height: 52.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Consonants.surface.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.power_settings_new_rounded,
                      size: 26.sp,
                      color: Consonants.surface,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    "You're currently offline",
                    style: AppText.screenTitle(
                      color: Consonants.surface,
                    ).copyWith(fontSize: 24.sp),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),
            AppButton(
              label: "Go online",
              icon: Icons.bolt_rounded,
              onPressed: onGoOnline,
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
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    // The parent Column is start-aligned, so without the full width this
    // shrink-wraps its widest child and the whole state hugs the left edge.
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Consonants.gutter.w,
          40.h,
          Consonants.gutter.w,
          0,
        ),
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
              child: Icon(
                Icons.directions_car_outlined,
                size: 34.sp,
                color: Consonants.iconInk,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              "No rides available right now",
              textAlign: TextAlign.center,
              style: AppText.sectionHeading().copyWith(fontSize: 18.sp),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RIDE SUMMARY CARD  — a claimable request is a tappable object, so it's a card
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
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
      child: AppCard(
        onTap: onViewDetails,
        padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 18.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _hostRow(),
            SizedBox(height: 18.h),
            _routeBlock(),
            SizedBox(height: 16.h),
            _metaRow(),
            SizedBox(height: 18.h),
            const AppDivider(),
            SizedBox(height: 16.h),
            _fareRow(),
            SizedBox(height: 16.h),
            _actionButtons(),
          ],
        ),
      ),
    );
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _scheduledLabel(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ap = dt.hour < 12 ? 'AM' : 'PM';
    return '${_months[dt.month - 1]} ${dt.day}, $h:$m $ap';
  }

  // ─── Host row ───────────────────────────────────────────
  Widget _hostRow() {
    return Row(
      children: [
        Container(
          width: 46.w,
          height: 46.w,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Consonants.indigoWash,
            shape: BoxShape.circle,
          ),
          child: Text(
            ride.hostInitial,
            style: AppText.amount(
              color: Consonants.indigo,
            ).copyWith(fontSize: 18.sp),
          ),
        ),
        SizedBox(width: 14.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ride.hostName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.rowLabel().copyWith(fontSize: 16.sp),
              ),
              SizedBox(height: 3.h),
              Text(
                "Trip host · ${ride.hostRating} · ${ride.riderCount} riders",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption().copyWith(fontSize: 12.5.sp),
              ),
            ],
          ),
        ),
        SizedBox(width: 10.w),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: Consonants.chipBg,
            borderRadius: BorderRadius.circular(Consonants.rPill.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isFemale ? Icons.female_outlined : Icons.male_outlined,
                size: 13.sp,
                color: Consonants.iconInk,
              ),
              SizedBox(width: 4.w),
              Text(
                _isFemale ? "Female" : "Male",
                style: AppText.navLabel(
                  color: Consonants.iconInk,
                ).copyWith(fontSize: 11.5.sp),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Route (pickup → drop) ──────────────────────────────
  Widget _routeBlock() {
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
            Container(width: 1.5, height: 26.h, color: Consonants.border),
            Icon(
              Icons.location_on_outlined,
              size: 14.sp,
              color: Consonants.iconInk,
            ),
          ],
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ride.startPoint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.rowLabel().copyWith(fontSize: 14.5.sp),
              ),
              SizedBox(height: 18.h),
              Text(
                ride.endPoint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.rowLabel().copyWith(fontSize: 14.5.sp),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Quick facts: scheduled-departure badge (when set) and the trip's length
  /// plus how far the pickup is from the driver.
  Widget _metaRow() {
    final r = ride.source;
    final chips = <Widget>[];
    if (r.isScheduled) {
      chips.add(
        _metaChip(
          Icons.schedule_rounded,
          _scheduledLabel(r.departureTime!),
          accent: true,
        ),
      );
    } else if (r.isDeparted) {
      // Its slot has passed — "Leave now" would be a lie.
      chips.add(
        _metaChip(
          Icons.history_rounded,
          'Departed ${_scheduledLabel(r.departureTime!)}',
        ),
      );
    } else {
      chips.add(_metaChip(Icons.bolt_rounded, 'Leave now', accent: true));
    }
    if (r.tripDistanceKm != null) {
      chips.add(
        _metaChip(
          Icons.straighten_rounded,
          '${r.tripDistanceKm!.toStringAsFixed(1)} km trip',
        ),
      );
    }
    if (r.tripDurationMin != null) {
      chips.add(
        _metaChip(Icons.access_time_rounded, '${r.tripDurationMin} min'),
      );
    }
    if (r.distanceKm != null) {
      chips.add(
        _metaChip(
          Icons.near_me_outlined,
          '${r.distanceKm!.toStringAsFixed(1)} km away',
        ),
      );
    }
    return Wrap(spacing: 8.w, runSpacing: 8.h, children: chips);
  }

  Widget _metaChip(IconData icon, String label, {bool accent = false}) {
    final fg = accent ? Consonants.indigo : Consonants.textMuted;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: accent ? Consonants.indigoWash : Consonants.canvas,
        borderRadius: BorderRadius.circular(Consonants.rPill.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.sp, color: fg),
          SizedBox(width: 5.w),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.navLabel(color: fg).copyWith(fontSize: 12.sp),
          ),
        ],
      ),
    );
  }

  // ─── Fare — the biggest thing on the card ───────────────
  Widget _fareRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Fare per rider",
                style: AppText.caption().copyWith(fontSize: 12.5.sp),
              ),
              SizedBox(height: 4.h),
              Text(
                "Rs ${ride.totalFare}",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.screenTitle().copyWith(fontSize: 24.sp),
              ),
            ],
          ),
        ),
        Text(
          "${ride.riderCount} riders",
          style: AppText.caption().copyWith(fontSize: 12.5.sp),
        ),
      ],
    );
  }

  // ─── Action buttons (Decline + View Details) ────────────
  Widget _actionButtons() {
    return Row(
      children: [
        // 3:4 rather than 1:2 — at a third of the row "Decline" truncated to
        // "De…". The primary still reads as the wider of the two.
        Expanded(
          flex: 3,
          child: AppButton(
            label: "Decline",
            kind: AppButtonKind.neutral,
            onPressed: onDecline,
          ),
        ),
        SizedBox(width: Consonants.gapButtons.w),
        Expanded(
          flex: 4,
          child: AppButton(label: "View details", onPressed: onViewDetails),
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
      riderCount: r.ridersJoined,
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
