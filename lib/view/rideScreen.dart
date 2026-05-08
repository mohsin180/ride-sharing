import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:ride_sharing/model/appRoutes.dart';
import 'package:ride_sharing/provider/directionsProvider.dart';
import 'package:ride_sharing/provider/rideRequestProvider.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

class Ridescreen extends ConsumerStatefulWidget {
  const Ridescreen({super.key});

  @override
  ConsumerState<Ridescreen> createState() => _RidescreenState();
}

/// Distance filter — passenger-side. "Nearest" is a sort (all results,
/// ranked by ascending distance); the others narrow the list.
enum _DistanceFilter { all, nearest, under5, under10 }

class _Ride {
  final String name;
  final String rating;
  final String trips;
  final int minutes;
  final double distanceKm;
  final String yourFare;
  final String avgRating;
  final String pickup;
  final String drop;
  final int seats;
  final LatLng pickupLatLng;
  final LatLng dropLatLng;

  const _Ride({
    required this.name,
    required this.rating,
    required this.trips,
    required this.minutes,
    required this.distanceKm,
    required this.yourFare,
    required this.avgRating,
    required this.pickup,
    required this.drop,
    required this.seats,
    required this.pickupLatLng,
    required this.dropLatLng,
  });
}

class _RidescreenState extends ConsumerState<Ridescreen> {
  late final TextEditingController _pickupController;
  late final TextEditingController _dropController;

  _DistanceFilter _filter = _DistanceFilter.all;

  // Demo data — real rides will come from the API. Distances are spread
  // across buckets so each filter pill has a visible effect.
  static const List<_Ride> _rides = [
    _Ride(
      name: "Sarah Ahmed",
      rating: "4.9",
      trips: "128",
      minutes: 18,
      distanceKm: 1.2,
      yourFare: "Rs 80",
      avgRating: "4.8",
      pickup: "Hostel City, Block B",
      drop: "Taramri Chowk",
      seats: 3,
      pickupLatLng: LatLng(33.6844, 73.1234),
      dropLatLng: LatLng(33.6920, 73.1500),
    ),
    _Ride(
      name: "Hina Malik",
      rating: "4.7",
      trips: "86",
      minutes: 22,
      distanceKm: 4.8,
      yourFare: "Rs 180",
      avgRating: "4.7",
      pickup: "Bahria Phase 7",
      drop: "Faizabad Metro",
      seats: 2,
      pickupLatLng: LatLng(33.5050, 73.1100),
      dropLatLng: LatLng(33.6700, 73.0930),
    ),
    _Ride(
      name: "Mariam Iqbal",
      rating: "4.8",
      trips: "204",
      minutes: 28,
      distanceKm: 7.6,
      yourFare: "Rs 250",
      avgRating: "4.9",
      pickup: "F-10 Markaz",
      drop: "Saddar",
      seats: 1,
      pickupLatLng: LatLng(33.6920, 73.0150),
      dropLatLng: LatLng(33.5950, 73.0500),
    ),
    _Ride(
      name: "Zara Iqbal",
      rating: "4.6",
      trips: "54",
      minutes: 36,
      distanceKm: 12.4,
      yourFare: "Rs 320",
      avgRating: "4.6",
      pickup: "I-8 Sector",
      drop: "Zero Point",
      seats: 2,
      pickupLatLng: LatLng(33.6680, 73.0700),
      dropLatLng: LatLng(33.6900, 73.0810),
    ),
  ];

  List<_Ride> get _filteredRides {
    switch (_filter) {
      case _DistanceFilter.all:
        return _rides;
      case _DistanceFilter.nearest:
        final sorted = List.of(_rides)
          ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        return sorted;
      case _DistanceFilter.under5:
        return _rides.where((r) => r.distanceKm < 5).toList();
      case _DistanceFilter.under10:
        return _rides.where((r) => r.distanceKm < 10).toList();
    }
  }

  @override
  void initState() {
    super.initState();
    // Hydrate the form from any previously-saved request so the
    // user doesn't lose their input when they navigate away and back.
    final saved = ref.read(rideRequestProvider);
    _pickupController = TextEditingController(text: saved.pickup);
    _dropController = TextEditingController(text: saved.drop);
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropController.dispose();
    super.dispose();
  }

  /// Save tap: persist the form to the provider and show feedback.
  /// Does NOT navigate away.
  void _onSaveTap() {
    final pickup = _pickupController.text.trim();
    final drop = _dropController.text.trim();
    if (pickup.isEmpty || drop.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        CustomWidgets.customErrorSnackBar(
          "Please enter pickup and destination",
        ),
      );
      return;
    }
    ref.read(rideRequestProvider.notifier).save(
          pickup: pickup,
          drop: drop,
          seats: ref.read(rideRequestProvider).seats,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      CustomWidgets.customSuccessSnackBar("Saved"),
    );
  }

  /// View Request tap (on the ride card): persist current form values,
  /// then navigate using the saved Riverpod state.
  void _onViewRequestTap() {
    final pickup = _pickupController.text.trim();
    final drop = _dropController.text.trim();
    if (pickup.isEmpty || drop.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        CustomWidgets.customErrorSnackBar(
          "Please enter pickup and destination",
        ),
      );
      return;
    }
    final state0 = ref.read(rideRequestProvider);
    final notifier = ref.read(rideRequestProvider.notifier);
    notifier.save(
      pickup: pickup,
      drop: drop,
      seats: state0.seats,
      pickupLatLng: state0.pickupLatLng,
      dropLatLng: state0.dropLatLng,
    );
    final state = ref.read(rideRequestProvider);
    // push (not go) so the back arrow on viewRequest can pop back here.
    context.push(
      Approutes.viewRequest,
      extra: <String, dynamic>{
        'pickup': state.pickup,
        'drop': state.drop,
        'seats': state.seats,
        'pickupLatLng': state.pickupLatLng,
        'dropLatLng': state.dropLatLng,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRides;
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(bottom: 24.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ScreenHeader(matchCount: filtered.length),
            SizedBox(height: 8.h),
            _searchForm(),
            SizedBox(height: 14.h),
            _FilterPills(
              selected: _filter,
              counts: _filterCounts,
              onSelect: (v) => setState(() => _filter = v),
            ),
            SizedBox(height: 14.h),
            if (filtered.isEmpty)
              _EmptyState(filter: _filter)
            else
              for (int i = 0; i < filtered.length; i++) ...[
                _FeaturedRideCard(
                  name: filtered[i].name,
                  rating: filtered[i].rating,
                  trips: filtered[i].trips,
                  minutes: filtered[i].minutes,
                  distance: filtered[i].distanceKm.toStringAsFixed(1),
                  yourFare: filtered[i].yourFare,
                  avgRating: filtered[i].avgRating,
                  pickup: filtered[i].pickup,
                  drop: filtered[i].drop,
                  seats: filtered[i].seats,
                  pickupLatLng: filtered[i].pickupLatLng,
                  dropLatLng: filtered[i].dropLatLng,
                  onViewRequest: _onViewRequestTap,
                  onDecline: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      CustomWidgets.customErrorSnackBar("Ride declined"),
                    );
                  },
                ),
                if (i != filtered.length - 1) SizedBox(height: 14.h),
              ],
            SizedBox(height: 14.h),
          ],
        ),
      ),
    );
  }

  /// Pre-computed counts for each filter pill so the badges stay
  /// stable regardless of which filter is currently selected.
  Map<_DistanceFilter, int> get _filterCounts => {
        _DistanceFilter.all: _rides.length,
        _DistanceFilter.nearest: _rides.length,
        _DistanceFilter.under5:
            _rides.where((r) => r.distanceKm < 5).length,
        _DistanceFilter.under10:
            _rides.where((r) => r.distanceKm < 10).length,
      };

  // ─────────────────────── SEARCH FORM ───────────────────────
  Widget _searchForm() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Consonants.primaryColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // ─── Pickup field ───
          Row(
            children: [
              Container(
                width: 14.w,
                height: 14.w,
                decoration: BoxDecoration(
                  color: Consonants.whiteColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Consonants.primaryColor,
                    width: 3,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _placesField(
                  controller: _pickupController,
                  hint: "Pickup location",
                  onPicked: (description, latLng) {
                    ref.read(rideRequestProvider.notifier).setPickup(
                          description,
                          latLng: latLng,
                        );
                  },
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Container(
              height: 1,
              color: Consonants.lightGreyColor,
            ),
          ),
          // ─── Destination field ───
          Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                size: 18.sp,
                color: const Color(0xffEF4444),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _placesField(
                  controller: _dropController,
                  hint: "Where are you going?",
                  onPicked: (description, latLng) {
                    ref.read(rideRequestProvider.notifier).setDrop(
                          description,
                          latLng: latLng,
                        );
                  },
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Container(
              height: 1,
              color: Consonants.lightGreyColor,
            ),
          ),
          // ─── Seats counter ───
          Row(
            children: [
              Icon(
                Icons.event_seat_rounded,
                size: 16.sp,
                color: Consonants.primaryColor,
              ),
              SizedBox(width: 10.w),
              CustomWidgets.customText(
                "Seats needed",
                12.sp,
                Consonants.boldTextColor,
                FontWeight.w600,
              ),
              const Spacer(),
              _seatStepper(),
            ],
          ),
          SizedBox(height: 14.h),
          // ─── Save button ───
          GestureDetector(
            onTap: _onSaveTap,
            child: Container(
              width: double.infinity,
              height: 46.h,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14.r),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Consonants.primaryColor,
                    Color(0xff5AC8FA),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        Consonants.primaryColor.withValues(alpha: 0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_added_rounded,
                    size: 16.sp,
                    color: Consonants.whiteColor,
                  ),
                  SizedBox(width: 6.w),
                  CustomWidgets.customText(
                    "Save",
                    13.sp,
                    Consonants.whiteColor,
                    FontWeight.w800,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Places-autocomplete-backed field. As the user types, suggestions
  /// appear in a dropdown; tapping one hydrates the controller and
  /// fires [onPicked] with the resolved coordinate (null when Place
  /// Details didn't return one).
  Widget _placesField({
    required TextEditingController controller,
    required String hint,
    required void Function(String description, LatLng? latLng) onPicked,
  }) {
    return GooglePlaceAutoCompleteTextField(
      textEditingController: controller,
      googleAPIKey: kGoogleMapsKey,
      debounceTime: 400,
      isLatLngRequired: true,
      countries: const ["pk"],
      inputDecoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 12.sp,
          color: Consonants.greyColor,
          fontWeight: FontWeight.w500,
          fontFamily: Consonants.fontFamily,
        ),
        border: InputBorder.none,
        isCollapsed: true,
        contentPadding: EdgeInsets.symmetric(vertical: 4.h),
      ),
      textStyle: TextStyle(
        fontSize: 12.sp,
        color: Consonants.boldTextColor,
        fontWeight: FontWeight.w700,
        fontFamily: Consonants.fontFamily,
      ),
      boxDecoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      itemClick: (Prediction p) {
        controller.text = p.description ?? '';
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
      },
      getPlaceDetailWithLatLng: (Prediction p) {
        final lat = double.tryParse(p.lat ?? '');
        final lng = double.tryParse(p.lng ?? '');
        onPicked(
          p.description ?? '',
          (lat != null && lng != null) ? LatLng(lat, lng) : null,
        );
      },
    );
  }

  Widget _seatStepper() {
    final seats = ref.watch(rideRequestProvider.select((s) => s.seats));
    final notifier = ref.read(rideRequestProvider.notifier);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Consonants.lightBlueColor,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seatButton(
            Icons.remove_rounded,
            enabled: seats > 1,
            onTap: () => notifier.setSeats(seats - 1),
          ),
          SizedBox(width: 12.w),
          SizedBox(
            width: 14.w,
            child: Center(
              child: CustomWidgets.customText(
                "$seats",
                13.sp,
                Consonants.boldTextColor,
                FontWeight.w800,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          _seatButton(
            Icons.add_rounded,
            enabled: seats < 6,
            onTap: () => notifier.setSeats(seats + 1),
          ),
        ],
      ),
    );
  }

  Widget _seatButton(
    IconData icon, {
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 24.w,
        height: 24.w,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled
              ? Consonants.primaryColor
              : Consonants.lightGreyColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 14.sp,
          color: enabled ? Consonants.whiteColor : Consonants.greyColor,
        ),
      ),
    );
  }
}

/// ───────────────────────── HEADER ─────────────────────────
class _ScreenHeader extends StatelessWidget {
  final int matchCount;
  const _ScreenHeader({required this.matchCount});

  @override
  Widget build(BuildContext context) {
    final subtitle = matchCount == 0
        ? "No rides match your filter"
        : matchCount == 1
            ? "1 ride matches your filter"
            : "$matchCount rides match your filter";
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomWidgets.customText(
            "Available Rides",
            18.sp,
            Consonants.boldTextColor,
            FontWeight.w700,
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
    );
  }
}

// ─────────────────────── FILTER PILLS ───────────────────────
// Distance pills: All / Nearest / < 5 km / < 10 km. Selected pill
// gets the project's signature gradient + glowing shadow; unselected
// pills are white with a soft drop shadow. Matches the design used by
// the driver-rides gender filter and the chat-list status filter.

class _FilterPills extends StatelessWidget {
  final _DistanceFilter selected;
  final Map<_DistanceFilter, int> counts;
  final ValueChanged<_DistanceFilter> onSelect;

  const _FilterPills({
    required this.selected,
    required this.counts,
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
            count: counts[_DistanceFilter.all] ?? 0,
            value: _DistanceFilter.all,
          ),
          SizedBox(width: 8.w),
          _pill(
            label: "Nearest",
            count: counts[_DistanceFilter.nearest] ?? 0,
            value: _DistanceFilter.nearest,
            icon: Icons.near_me_rounded,
          ),
          SizedBox(width: 8.w),
          _pill(
            label: "< 5 km",
            count: counts[_DistanceFilter.under5] ?? 0,
            value: _DistanceFilter.under5,
          ),
          SizedBox(width: 8.w),
          _pill(
            label: "< 10 km",
            count: counts[_DistanceFilter.under10] ?? 0,
            value: _DistanceFilter.under10,
          ),
        ],
      ),
    );
  }

  Widget _pill({
    required String label,
    required int count,
    required _DistanceFilter value,
    IconData? icon,
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
                color: isSelected
                    ? Consonants.whiteColor
                    : Consonants.primaryColor,
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

// ─────────────────────── EMPTY STATE ────────────────────────

class _EmptyState extends StatelessWidget {
  final _DistanceFilter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final label = switch (filter) {
      _DistanceFilter.under5 => "No rides within 5 km right now",
      _DistanceFilter.under10 => "No rides within 10 km right now",
      _DistanceFilter.nearest => "No rides nearby right now",
      _DistanceFilter.all => "No rides available right now",
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
            "Try a wider distance to see more rides",
            11.sp,
            Consonants.greyColor,
            FontWeight.w500,
          ),
        ],
      ),
    );
  }
}

/// ─────────────────── FEATURED RIDE CARD ───────────────────
/// Mirrors the driver-side ride summary card (`driverRides.dart`):
/// gradient host strip → 3 stat tiles → route timeline → distance /
/// duration strip → Decline + View Request buttons.
///
/// Difference from the driver version: the middle stat tile shows the
/// *current passenger's* fare ("Your fare") rather than the trip's
/// total fare, since the driver sees aggregate while the passenger
/// sees only what they'll personally pay.
class _FeaturedRideCard extends StatelessWidget {
  final String name;
  final String rating;
  final String trips;
  final int minutes;
  final String distance;
  final String yourFare;
  final String avgRating;
  final String pickup;
  final String drop;
  final int seats;
  final LatLng? pickupLatLng;
  final LatLng? dropLatLng;
  final VoidCallback onViewRequest;
  final VoidCallback onDecline;

  const _FeaturedRideCard({
    required this.name,
    required this.rating,
    required this.trips,
    required this.minutes,
    required this.distance,
    required this.yourFare,
    required this.avgRating,
    required this.pickup,
    required this.drop,
    required this.seats,
    this.pickupLatLng,
    this.dropLatLng,
    required this.onViewRequest,
    required this.onDecline,
  });

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
                _LiveDistanceStrip(
                  pickupLatLng: pickupLatLng,
                  dropLatLng: dropLatLng,
                  fallbackDistance: distance,
                  fallbackMinutes: minutes,
                ),
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
    final initial =
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : "?";
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
              initial,
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
                        name,
                        14.sp,
                        Consonants.whiteColor,
                        FontWeight.w800,
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
                      "$rating  ·  $trips trips",
                      10.sp,
                      Consonants.whiteColor.withValues(alpha: 0.95),
                      FontWeight.w600,
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
                Icon(Icons.female_rounded,
                    size: 11.sp, color: const Color(0xffEC4899)),
                SizedBox(width: 3.w),
                CustomWidgets.customText(
                  "Female",
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

  // ─── Stats: your fare / avg rating / riders ─────────────
  Widget _statsPills() {
    return Row(
      children: [
        Expanded(
          child: _statTile(
            icon: Icons.payments_rounded,
            value: yourFare,
            label: "Your fare",
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _statTile(
            icon: Icons.star_rounded,
            value: avgRating,
            label: "Avg rating",
            iconColor: const Color(0xffF5B800),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _statTile(
            icon: Icons.people_alt_rounded,
            value: "$seats",
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
                pickup,
                12.sp,
                Consonants.boldTextColor,
                FontWeight.w700,
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
                drop,
                12.sp,
                Consonants.boldTextColor,
                FontWeight.w700,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Action buttons (Decline + View Request) ───────────
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
            onTap: onViewRequest,
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
                    "View Request",
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

// ─────────────────── LIVE DISTANCE / DURATION STRIP ──────────────────
// When pickup/drop coordinates are known we hit the Directions API for
// real km + min via [directionsProvider]; while loading we render the
// caller-supplied fallback (the static demo numbers) so the card never
// flashes empty. On any error we also fall back so a missing API key
// can't blank out the screen.

class _LiveDistanceStrip extends ConsumerWidget {
  final LatLng? pickupLatLng;
  final LatLng? dropLatLng;
  final String fallbackDistance; // e.g. "12.4"
  final int fallbackMinutes;

  const _LiveDistanceStrip({
    required this.pickupLatLng,
    required this.dropLatLng,
    required this.fallbackDistance,
    required this.fallbackMinutes,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String distanceText = "$fallbackDistance km";
    String minutesText = "$fallbackMinutes min";

    if (pickupLatLng != null && dropLatLng != null) {
      final async = ref.watch(directionsProvider(DirectionsRequest(
        origin: pickupLatLng!,
        destination: dropLatLng!,
      )));
      async.whenData((r) {
        distanceText = "${r.distanceKm.toStringAsFixed(1)} km";
        minutesText = "${r.durationMinutes} min";
      });
    }

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
            distanceText,
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
            minutesText,
            11.sp,
            Consonants.primaryColor,
            FontWeight.w800,
          ),
        ],
      ),
    );
  }
}
