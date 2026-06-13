import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/provider/mapProvider.dart';
import 'package:ride_sharing/provider/rideRequestProvider.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';
import 'package:ride_sharing/widgets/maps/placeSearchField.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Ride option model + static data
// ─────────────────────────────────────────────────────────────────────────────

class RideOption {
  final String title;
  
  final IconData icon;
  final Color color;

  const RideOption({
    required this.title,
    
    required this.icon,
    required this.color,
  });
}

const List<RideOption> kRideOptions = [
  RideOption(
    title: 'Economy',
    
    icon: Icons.directions_car_filled_rounded,
    color: Consonants.lightBlueColor,
  ),
  RideOption(
    title: 'Premium',
     
    icon: Icons.car_rental_rounded,
    color: Consonants.primaryGreenColor,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Top-level sheet — draggable, composes all sub-sections
// ─────────────────────────────────────────────────────────────────────────────

/// Draggable bottom sheet containing the pickup/drop-off inputs,
/// quick-action chips, ride option cards and the sticky CTA.
///
/// Size bounds adapt to orientation via [MediaQuery].
class HomeBookingSheet extends StatelessWidget {
  /// Called when the user taps Book. Pass `null` to disable the CTA
  /// (e.g. while a request is in flight). The future is awaited so
  /// callers can show a loading indicator via [isBooking].
  final Future<void> Function()? onBookPressed;

  /// When true, the CTA shows a spinner instead of the label and
  /// rejects taps (in addition to [onBookPressed] being null).
  final bool isBooking;

  const HomeBookingSheet({
    super.key,
    required this.onBookPressed,
    this.isBooking = false,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return DraggableScrollableSheet(
      initialChildSize: isLandscape ? 0.55 : 0.42,
      minChildSize: 0.25,
      maxChildSize: isLandscape ? 0.9 : 0.85,
      builder: (context, scrollController) {
        return _SheetBody(
          scrollController: scrollController,
          onBookPressed: onBookPressed,
          isBooking: isBooking,
        );
      },
    );
  }
}

class _SheetBody extends StatelessWidget {
  final ScrollController scrollController;
  final Future<void> Function()? onBookPressed;
  final bool isBooking;

  const _SheetBody({
    required this.scrollController,
    required this.onBookPressed,
    required this.isBooking,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Consonants.whiteColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              const _DragHandle(),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 16.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomWidgets.customText(
                        'Where are you going?',
                        15.sp,
                        Consonants.boldTextColor,
                        FontWeight.w700,
                      ),
                      SizedBox(height: 14.h),
                      const _LocationFields(),
                      SizedBox(height: 18.h),
                      const _SeatsPicker(),
                      SizedBox(height: 18.h),
                      CustomWidgets.customText(
                        'Choose a ride',
                        13.sp,
                        Consonants.boldTextColor,
                        FontWeight.w700,
                      ),
                      SizedBox(height: 10.h),
                      _RideOptionsList(availableWidth: constraints.maxWidth),
                      SizedBox(height: 12.h),
                    ],
                  ),
                ),
              ),
              _StickyCta(
                onPressed: onBookPressed,
                isLoading: isBooking,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 10.h, bottom: 6.h),
      child: Container(
        height: 5.h,
        width: 44.w,
        decoration: BoxDecoration(
          color: Consonants.lightGreyColor,
          borderRadius: BorderRadius.circular(4.r),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Location fields — pickup is driven by the pickup provider (read-only),
// drop-off is a real editable field.
// ─────────────────────────────────────────────────────────────────────────────

class _LocationFields extends StatelessWidget {
  const _LocationFields();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: Consonants.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: [
          const _PickupRow(),
          Divider(
            height: 1,
            color: Consonants.lightGreyColor,
            indent: 30.w,
          ),
          const _DropoffRow(),
        ],
      ),
    );
  }
}

/// Isolated in its own [Consumer] so that map camera moves only rebuild
/// this tiny subtree — not the whole sheet. Resolves the current
/// [pickupLocationProvider] LatLng to a real address via
/// [pickupAddressProvider]; falls back to a coords label if the
/// reverse-geocode hasn't resolved or fails.
class _PickupRow extends ConsumerWidget {
  const _PickupRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pickup = ref.watch(pickupLocationProvider);
    final addressAsync = ref.watch(pickupAddressProvider);

    // Pickup is now `latlong2.LatLng?` (post mapProvider migration). The
    // helper used to take Google's LatLng — switched to plain doubles so
    // this row stays type-agnostic until homeBookingSheet itself migrates
    // off google_places_flutter in Stage 3.
    final label = pickup == null
        ? 'Detecting location…'
        : addressAsync.maybeWhen(
            data: (a) => (a == null || a.isEmpty)
                ? _coordsLabel(pickup.latitude, pickup.longitude)
                : a,
            orElse: () =>
                _coordsLabel(pickup.latitude, pickup.longitude),
          );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 14.h),
      child: Row(
        children: [
          Icon(
            Icons.my_location_rounded,
            color: Consonants.primaryColor,
            size: 18.sp,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: Consonants.fontFamily,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Consonants.boldTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Lat/lng → "31.52040, 74.35870". Takes raw doubles instead of a
  /// LatLng so the row works with whatever coordinate type the pickup
  /// provider returns (Google's LatLng pre-migration, latlong2's now).
  String _coordsLabel(double lat, double lon) =>
      '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}';
}

/// Places-autocomplete drop-off field. Suggestions render in a dropdown
/// below the field as the user types; tapping a prediction populates
/// the text controller AND writes the coords into [rideRequestProvider]
/// so downstream Directions calls can use them.
class _DropoffRow extends ConsumerStatefulWidget {
  const _DropoffRow();

  @override
  ConsumerState<_DropoffRow> createState() => _DropoffRowState();
}

class _DropoffRowState extends ConsumerState<_DropoffRow> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Hydrate from any persisted drop value so the field survives
    // tab switches.
    final saved = ref.read(rideRequestProvider).drop;
    if (saved.isNotEmpty) _controller.text = saved;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Bias autocomplete toward the user's current pickup so suggestions
    // near them rank higher — significantly better UX than alphabetical.
    final bias = ref.watch(pickupLocationProvider);

    return Row(
      children: [
        Icon(
          Icons.location_on_rounded,
          color: Colors.redAccent,
          size: 18.sp,
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: PlaceSearchField(
            controller: _controller,
            hint: 'Where to?',
            bias: bias,
            inputDecoration: InputDecoration(
              isDense: true,
              hintText: 'Where to?',
              hintStyle: TextStyle(
                fontFamily: Consonants.fontFamily,
                fontSize: 12.sp,
                color: Consonants.greyColor,
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 14.h),
            ),
            textStyle: TextStyle(
              fontFamily: Consonants.fontFamily,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: Consonants.boldTextColor,
            ),
            onPicked: (s) {
              ref
                  .read(rideRequestProvider.notifier)
                  .setDrop(s.formatted, latLng: s.coords);
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Seats picker — small chip row, writes through to [rideRequestProvider]
// so the selected seat count is in scope for the sticky CTA, viewRequest
// screen, and any backend submission. 1–4 covers the common case; the
// underlying notifier still clamps to [1, 6] in case other entry points
// pass higher values.
// ─────────────────────────────────────────────────────────────────────────────

class _SeatsPicker extends ConsumerWidget {
  const _SeatsPicker();

  static const _options = [1, 2, 3, 4];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSeats = ref.watch(
      rideRequestProvider.select((s) => s.seats),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.event_seat_rounded,
                size: 14.sp, color: Consonants.primaryColor),
            SizedBox(width: 6.w),
            CustomWidgets.customText(
              "How many seats?",
              13.sp,
              Consonants.boldTextColor,
              FontWeight.w700,
            ),
            SizedBox(width: 6.w),
            CustomWidgets.customText(
              selectedSeats == 1 ? "1 seat" : "$selectedSeats seats",
              11.sp,
              Consonants.primaryColor,
              FontWeight.w700,
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Row(
          children: [
            for (int i = 0; i < _options.length; i++) ...[
              Expanded(
                child: _SeatChip(
                  count: _options[i],
                  isSelected: selectedSeats == _options[i],
                  onTap: () => ref
                      .read(rideRequestProvider.notifier)
                      .setSeats(_options[i]),
                ),
              ),
              if (i != _options.length - 1) SizedBox(width: 8.w),
            ],
          ],
        ),
      ],
    );
  }
}

class _SeatChip extends StatelessWidget {
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _SeatChip({
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 56.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
                )
              : null,
          color: isSelected ? null : Consonants.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : Consonants.lightGreyColor,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Consonants.primaryColor.withValues(alpha: 0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_rounded,
              size: 14.sp,
              color: isSelected
                  ? Consonants.whiteColor
                  : Consonants.primaryColor,
            ),
            SizedBox(height: 2.h),
            CustomWidgets.customText(
              "$count",
              14.sp,
              isSelected ? Consonants.whiteColor : Consonants.boldTextColor,
              FontWeight.w800,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ride options — horizontal scroll (narrow) or stretched row (wide)
// ─────────────────────────────────────────────────────────────────────────────

class _RideOptionsList extends ConsumerWidget {
  final double availableWidth;

  const _RideOptionsList({required this.availableWidth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedRideIndexProvider);
    final useStretched = availableWidth >= 520;

    if (useStretched) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < kRideOptions.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: i == kRideOptions.length - 1 ? 0 : 10.w,
                ),
                child: _RideCard(
                  option: kRideOptions[i],
                  selected: selected == i,
                  onTap: () =>
                      ref.read(selectedRideIndexProvider.notifier).select(i),
                ),
              ),
            ),
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < kRideOptions.length; i++) ...[
              ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: 140.w,
                  maxWidth: 170.w,
                ),
                child: _RideCard(
                  option: kRideOptions[i],
                  selected: selected == i,
                  onTap: () =>
                      ref.read(selectedRideIndexProvider.notifier).select(i),
                ),
              ),
              if (i != kRideOptions.length - 1) SizedBox(width: 10.w),
            ],
          ],
        ),
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  final RideOption option;
  final bool selected;
  final VoidCallback onTap;

  const _RideCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(12.r),
          decoration: BoxDecoration(
            color: selected
                ? Consonants.primaryColor.withValues(alpha: 0.08)
                : Consonants.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: selected ? Consonants.primaryColor : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: option.color,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  option.icon,
                  color: Consonants.boldTextColor,
                  size: 18.sp,
                ),
              ),
              SizedBox(height: 8.h),
              CustomWidgets.customText(
                option.title,
                12.sp,
                Consonants.boldTextColor,
                FontWeight.w700,
              ),
              SizedBox(height: 2.h),
              
              
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky CTA — label reflects selected ride
// ─────────────────────────────────────────────────────────────────────────────

class _StickyCta extends ConsumerWidget {
  final Future<void> Function()? onPressed;
  final bool isLoading;

  const _StickyCta({required this.onPressed, this.isLoading = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedRideIndexProvider);
    final seats = ref.watch(rideRequestProvider.select((s) => s.seats));
    final selected = kRideOptions[selectedIndex];
    final seatLabel = seats == 1 ? '1 seat' : '$seats seats';

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 14.h),
        child: _PressableButton(
          label: 'Book ${selected.title} · $seatLabel ',
          onPressed: onPressed,
          isLoading: isLoading,
        ),
      ),
    );
  }
}

class _PressableButton extends StatefulWidget {
  final String label;
  final Future<void> Function()? onPressed;
  final bool isLoading;

  const _PressableButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  State<_PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<_PressableButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.isLoading || widget.onPressed == null;

    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapCancel: disabled ? null : () => setState(() => _pressed = false),
      onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
      onTap: disabled ? null : () => widget.onPressed?.call(),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 54.h,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: disabled
                ? Consonants.primaryColor.withValues(alpha: 0.7)
                : Consonants.primaryColor,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: Consonants.primaryColor.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: widget.isLoading
              ? SizedBox(
                  height: 22.h,
                  width: 22.h,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Consonants.whiteColor,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_taxi_rounded,
                      color: Consonants.whiteColor,
                      size: 18.sp,
                    ),
                    SizedBox(width: 8.w),
                    Flexible(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: Consonants.fontFamily,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: Consonants.whiteColor,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
