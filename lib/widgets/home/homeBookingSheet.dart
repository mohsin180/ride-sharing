import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/provider/mapProvider.dart';
import 'package:ride_sharing/provider/rideRequestProvider.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/appComponents.dart';
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
    icon: Icons.directions_car_outlined,
    color: Consonants.indigoWash,
  ),
  RideOption(
    title: 'Premium',
    icon: Icons.local_taxi_outlined,
    color: Consonants.chipBg,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Top-level sheet — draggable, composes all sub-sections
// ─────────────────────────────────────────────────────────────────────────────

/// Draggable bottom sheet containing the pickup/drop-off inputs,
/// quick-action chips, ride option cards and the sticky CTA.
///
/// Size bounds adapt to orientation via [MediaQuery], capped at the system's
/// 82% sheet ceiling so the map is never fully covered.
class HomeBookingSheet extends StatefulWidget {
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
  State<HomeBookingSheet> createState() => _HomeBookingSheetState();
}

class _HomeBookingSheetState extends State<HomeBookingSheet> {
  /// Drives the sheet from the handle, which sits outside the scroll view and
  /// so can't move it on its own.
  final _sheet = DraggableScrollableController();

  static const _minSize = 0.25;
  static const _maxSize = 0.82;

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  /// Handle drags move the sheet directly: translate the finger's travel into
  /// a fraction of the screen and set the extent.
  void _onHandleDrag(DragUpdateDetails d) {
    if (!_sheet.isAttached) return;
    final height = MediaQuery.of(context).size.height;
    if (height == 0) return;
    final next = (_sheet.size - d.delta.dy / height).clamp(_minSize, _maxSize);
    _sheet.jumpTo(next);
  }

  /// Tapping the handle toggles between the resting and expanded heights, so
  /// the sheet is reachable without a drag at all.
  void _onHandleTap(double restingSize) {
    if (!_sheet.isAttached) return;
    _sheet.animateTo(
      _sheet.size > (restingSize + _maxSize) / 2 ? restingSize : _maxSize,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final restingSize = isLandscape ? 0.55 : 0.42;

    return DraggableScrollableSheet(
      controller: _sheet,
      initialChildSize: restingSize,
      minChildSize: _minSize,
      maxChildSize: _maxSize,
      snap: true,
      snapSizes: [restingSize],
      builder: (context, scrollController) {
        return _SheetBody(
          scrollController: scrollController,
          onBookPressed: widget.onBookPressed,
          isBooking: widget.isBooking,
          onHandleDrag: _onHandleDrag,
          onHandleTap: () => _onHandleTap(restingSize),
        );
      },
    );
  }
}

class _SheetBody extends StatelessWidget {
  final ScrollController scrollController;
  final Future<void> Function()? onBookPressed;
  final bool isBooking;
  final ValueChanged<DragUpdateDetails> onHandleDrag;
  final VoidCallback onHandleTap;

  const _SheetBody({
    required this.scrollController,
    required this.onBookPressed,
    required this.isBooking,
    required this.onHandleDrag,
    required this.onHandleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Consonants.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(Consonants.rSheet.r)),
        boxShadow: Consonants.sheetLift,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: onHandleDrag,
                onTap: onHandleTap,
                child: const _DragHandle(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  // Always scrollable so a drag on the content is handed to
                  // the sheet even when the content already fits; with
                  // clamping physics there was nothing to pass on and the
                  // sheet wouldn't move.
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                      Consonants.gutter.w, 0, Consonants.gutter.w, 8.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Where are you going?',
                        style:
                            AppText.sectionHeading().copyWith(fontSize: 18.sp),
                      ),
                      SizedBox(height: 16.h),
                      const _LocationFields(),
                      SizedBox(height: 24.h),
                      const _SeatsPicker(),
                      SizedBox(height: 22.h),
                      Text(
                        'Choose a ride',
                        style: AppText.rowLabel(color: Consonants.headingInk)
                            .copyWith(
                                fontSize: 15.sp, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 12.h),
                      _RideOptionsList(availableWidth: constraints.maxWidth),
                      SizedBox(height: 8.h),
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
    // 44x5 grabber with 14px of air under it — the system's sheet header.
    // The row spans the full width so the whole header is a drag target; the
    // grabber alone is a 44px-wide thing to hit.
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.only(top: 16.h, bottom: 14.h),
        child: Center(
          child: Container(
            height: 5.h,
            width: 44.w,
            decoration: BoxDecoration(
              color: const Color(0xFFD6D6E2),
              borderRadius: BorderRadius.circular(Consonants.rPill.r),
            ),
          ),
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
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: Consonants.canvas,
        borderRadius: BorderRadius.circular(Consonants.rInput.r),
      ),
      child: Column(
        children: [
          const _PickupRow(),
          Padding(
            padding: EdgeInsets.only(left: 32.w),
            child: const AppDivider(),
          ),
          const _DropoffRow(),
        ],
      ),
    );
  }
}

/// The leading slot of a location row. A hollow indigo ring marks where the
/// trip starts, a solid violet square where it ends — same 20px column so the
/// two labels stay on one optical line.
class _RouteMarker extends StatelessWidget {
  final bool isOrigin;

  const _RouteMarker({required this.isOrigin});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20.w,
      child: Center(
        child: isOrigin
            ? Container(
                width: 11.w,
                height: 11.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Consonants.indigo, width: 3),
                ),
              )
            : Container(
                width: 10.w,
                height: 10.w,
                decoration: BoxDecoration(
                  color: Consonants.violet,
                  borderRadius: BorderRadius.circular(3.r),
                ),
              ),
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
      padding: EdgeInsets.symmetric(vertical: 15.h),
      child: Row(
        children: [
          const _RouteMarker(isOrigin: true),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.rowLabel(color: Consonants.headingInk)
                  .copyWith(fontSize: 15.sp, fontWeight: FontWeight.w600),
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
        const _RouteMarker(isOrigin: false),
        SizedBox(width: 12.w),
        Expanded(
          child: PlaceSearchField(
            controller: _controller,
            hint: 'Where to?',
            bias: bias,
            inputDecoration: InputDecoration(
              isDense: true,
              hintText: 'Where to?',
              hintStyle: AppText.rowLabel(color: Consonants.textMuted)
                  .copyWith(fontSize: 15.sp),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 15.h),
            ),
            textStyle: AppText.rowLabel(color: Consonants.headingInk)
                .copyWith(fontSize: 15.sp, fontWeight: FontWeight.w600),
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
            Icon(Icons.event_seat_outlined,
                size: 18.sp, color: Consonants.iconInk),
            SizedBox(width: 10.w),
            Text(
              'How many seats?',
              style: AppText.rowLabel(color: Consonants.headingInk)
                  .copyWith(fontSize: 15.sp, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              selectedSeats == 1 ? '1 seat' : '$selectedSeats seats',
              style: AppText.caption(color: Consonants.indigo)
                  .copyWith(fontSize: 12.5.sp, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        SizedBox(height: 12.h),
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
              if (i != _options.length - 1) SizedBox(width: 10.w),
            ],
          ],
        ),
      ],
    );
  }
}

/// Selection reads as an indigo wash behind an indigo rule — the action
/// gradient is reserved for the Book button at the bottom of the sheet.
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
    final ink = isSelected ? Consonants.indigo : Consonants.textMuted;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 56.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Consonants.indigoWash : Consonants.canvas,
          borderRadius: BorderRadius.circular(Consonants.rCard.r),
          border: Border.all(
            color: isSelected ? Consonants.indigo : Consonants.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_outline_rounded, size: 15.sp, color: ink),
            SizedBox(height: 2.h),
            Text(
              '$count',
              style: AppText.amount(
                color: isSelected ? Consonants.indigo : Consonants.headingInk,
              ).copyWith(fontSize: 15.sp),
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
                  right: i == kRideOptions.length - 1 ? 0 : Consonants.gapTiles.w,
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
              if (i != kRideOptions.length - 1)
                SizedBox(width: Consonants.gapTiles.w),
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
        borderRadius: BorderRadius.circular(Consonants.rCard.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: selected ? Consonants.indigoWash : Consonants.canvas,
            borderRadius: BorderRadius.circular(Consonants.rCard.r),
            border: Border.all(
              color: selected ? Consonants.indigo : Consonants.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 38.w,
                    height: 38.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? Consonants.surface : option.color,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                      option.icon,
                      color: Consonants.iconInk,
                      size: 20.sp,
                    ),
                  ),
                  const Spacer(),
                  // A quiet tick rather than a second gradient.
                  AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 18.sp,
                      color: Consonants.indigo,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Text(
                option.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.rowLabel(
                  color: selected ? Consonants.indigo : Consonants.headingInk,
                ).copyWith(fontSize: 14.5.sp, fontWeight: FontWeight.w600),
              ),
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Hairline so the CTA reads as a floor to the scrolling content
        // rather than the last item in it.
        const AppDivider(),
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                Consonants.gutter.w, 16.h, Consonants.gutter.w, 16.h),
            child: _PressableButton(
              label: 'Book ${selected.title} · $seatLabel',
              onPressed: onPressed,
              isLoading: isLoading,
            ),
          ),
        ),
      ],
    );
  }
}

/// The one gradient on the sheet. Kept as a hand-rolled button rather than
/// [AppButton] purely for the press-scale — everything else (fill, radius,
/// type) is the system's primary spec.
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
        child: Opacity(
          opacity: disabled ? 0.55 : 1,
          child: Container(
            height: 56.h,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: Consonants.actionGradient,
              borderRadius: BorderRadius.circular(Consonants.rButton.r),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x3DA044FF),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: widget.isLoading
                ? SizedBox(
                    height: 22.h,
                    width: 22.h,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Consonants.surface,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.local_taxi_rounded,
                        color: Consonants.surface,
                        size: 19.sp,
                      ),
                      SizedBox(width: 10.w),
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.button().copyWith(fontSize: 16.sp),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
