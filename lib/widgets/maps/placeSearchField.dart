import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart';
import 'package:ride_sharing/model/placeModels.dart';
import 'package:ride_sharing/provider/mapProvider.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/appComponents.dart';

/// Drop-in replacement for `GooglePlaceAutoCompleteTextField`.
///
/// Renders a [TextField] and, while focused with non-empty input, a
/// floating overlay dropdown with autocomplete suggestions from
/// Geoapify. Tapping a suggestion fills the controller and fires
/// [onPicked] with the resolved [PlaceSuggestion] (which carries the
/// coords) — same callback shape the old widget had.
///
/// Implementation notes:
/// - Uses [OverlayPortal] (Flutter 3.10+) so the dropdown floats over
///   sibling widgets without consuming layout space — important inside
///   the booking sheet and the ride-screen scroll view.
/// - Debounces typing at 300ms to avoid burning Geoapify quota on
///   every keystroke (free tier is 3,000/day).
/// - Closes on outside taps (via [TapRegion]) and on suggestion tap.
class PlaceSearchField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final String hint;

  /// Called when the user taps a suggestion. Receives the full
  /// [PlaceSuggestion] so callers get coords + formatted address in
  /// one shot.
  final void Function(PlaceSuggestion suggestion) onPicked;

  /// Restrict autocomplete to a country (ISO 3166-1 alpha-2). Defaults
  /// to "pk" to match the previous Google config; pass null to search
  /// globally.
  final String? countryCode;

  /// Optional proximity bias — suggestions near this point rank higher.
  /// Pass the user's GPS fix or the map center for better relevance.
  final LatLng? bias;

  /// Decoration for the *text field* itself. The dropdown styles itself.
  final InputDecoration inputDecoration;

  /// Style applied to the typed text.
  final TextStyle? textStyle;

  /// Container styling around the field (border radius, shadow). Same
  /// shape as the old widget's `boxDecoration`.
  final BoxDecoration? boxDecoration;

  const PlaceSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onPicked,
    this.countryCode = 'pk',
    this.bias,
    InputDecoration? inputDecoration,
    this.textStyle,
    this.boxDecoration,
  }) : inputDecoration = inputDecoration ?? const InputDecoration();

  @override
  ConsumerState<PlaceSearchField> createState() => _PlaceSearchFieldState();
}

class _PlaceSearchFieldState extends ConsumerState<PlaceSearchField> {
  final _layerLink = LayerLink();
  final _overlayController = OverlayPortalController();
  final _focusNode = FocusNode();

  /// Shared identity used by the two [TapRegion]s — one wrapping the
  /// field, one wrapping the overlay dropdown. Without this, taps on
  /// suggestions register as "outside" the field's TapRegion (since
  /// the overlay child renders in the root Overlay, not inside the
  /// field's widget subtree) and dismiss the dropdown before InkWell
  /// can fire. Sharing a groupId tells Flutter both regions are the
  /// same logical hit area.
  final Object _tapRegionGroup = Object();

  Timer? _debounce;

  /// Monotonically-increasing query id. Late-arriving responses for a
  /// stale query (user kept typing) get dropped on receipt — prevents
  /// the older request "winning" the race.
  int _queryId = 0;

  List<PlaceSuggestion> _suggestions = const [];
  bool _loading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // Keep the dropdown only visible while the field is focused; closing
    // it on blur stops it from clinging to the screen during navigation.
    if (!_focusNode.hasFocus) {
      _overlayController.hide();
    } else if (_suggestions.isNotEmpty || _loading) {
      _overlayController.show();
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _suggestions = const [];
        _loading = false;
        _hasSearched = false;
      });
      _overlayController.hide();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(value));
  }

  Future<void> _search(String text) async {
    final myId = ++_queryId;
    setState(() => _loading = true);
    if (_focusNode.hasFocus) _overlayController.show();

    try {
      final results =
          await ref.read(geocodingServiceProvider).autocomplete(
                text,
                bias: widget.bias,
                countryCode: widget.countryCode,
              );
      if (!mounted || myId != _queryId) return;
      setState(() {
        _suggestions = results;
        _loading = false;
        _hasSearched = true;
      });
    } catch (_) {
      if (!mounted || myId != _queryId) return;
      setState(() {
        _suggestions = const [];
        _loading = false;
        _hasSearched = true;
      });
    }
  }

  void _select(PlaceSuggestion s) {
    widget.controller.text = s.formatted;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: widget.controller.text.length),
    );
    widget.onPicked(s);
    _overlayController.hide();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: _tapRegionGroup,
      onTapOutside: (_) => _overlayController.hide(),
      child: CompositedTransformTarget(
        link: _layerLink,
        child: OverlayPortal(
          controller: _overlayController,
          overlayChildBuilder: _buildOverlay,
          child: Container(
            decoration: widget.boxDecoration,
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onChanged: _onChanged,
              cursorColor: Consonants.violet,
              style: widget.textStyle ??
                  AppText.rowLabel(color: Consonants.headingInk)
                      .copyWith(fontSize: 15.sp),
              decoration: _decoration(),
            ),
          ),
        ),
      ),
    );
  }

  /// The caller's decoration wins wherever it says something; anything it
  /// leaves unset falls back to the design system's input — r16, 17/18
  /// padding, resting [Consonants.border], violet on focus. Callers that
  /// draw their own chrome (the booking sheet, the ride screen) pass
  /// `InputBorder.none` and keep it.
  InputDecoration _decoration() {
    final d = widget.inputDecoration;
    return d.copyWith(
      hintText: d.hintText ?? widget.hint,
      hintStyle: d.hintStyle ??
          AppText.rowLabel(color: Consonants.textMuted)
              .copyWith(fontSize: 15.sp),
      contentPadding: d.contentPadding ??
          EdgeInsets.symmetric(vertical: 17.h, horizontal: 18.w),
      prefixIcon: d.prefixIcon ??
          (d.border == InputBorder.none
              ? null
              : Padding(
                  padding: EdgeInsets.only(left: 18.w, right: 12.w),
                  child: Icon(
                    Icons.search_rounded,
                    size: 20.sp,
                    color: Consonants.iconInk,
                  ),
                )),
      prefixIconConstraints: d.prefixIconConstraints ??
          const BoxConstraints(minWidth: 0, minHeight: 0),
      border: d.border ?? _fieldBorder(Consonants.border),
      enabledBorder:
          d.enabledBorder ?? d.border ?? _fieldBorder(Consonants.border),
      focusedBorder: d.focusedBorder ??
          d.border ??
          _fieldBorder(Consonants.violet, width: 1.8),
    );
  }

  OutlineInputBorder _fieldBorder(Color colour, {double width = 1.2}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(Consonants.rInput.r),
        borderSide: BorderSide(color: colour, width: width),
      );

  Widget _buildOverlay(BuildContext context) {
    // leaderSize comes from the LayerLink and is null on the first frame
    // — fall back to a sensible default while it resolves.
    final width = _layerLink.leaderSize?.width ?? 280;

    return Positioned(
      width: width,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 6),
        // Same groupId as the field's TapRegion so taps on suggestions
        // don't fire `onTapOutside` and dismiss the dropdown.
        child: TapRegion(
          groupId: _tapRegionGroup,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Consonants.rCard.r),
              boxShadow: Consonants.cardLift,
            ),
            child: Material(
              color: Consonants.surface,
              elevation: 0,
              borderRadius: BorderRadius.circular(Consonants.rCard.r),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 240.h),
                child: _DropdownContent(
                  loading: _loading,
                  suggestions: _suggestions,
                  hasSearched: _hasSearched,
                  onTap: _select,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownContent extends StatelessWidget {
  final bool loading;
  final bool hasSearched;
  final List<PlaceSuggestion> suggestions;
  final void Function(PlaceSuggestion) onTap;

  const _DropdownContent({
    required this.loading,
    required this.hasSearched,
    required this.suggestions,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 18.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 15.w,
              height: 15.w,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: Consonants.violet,
              ),
            ),
            SizedBox(width: 10.w),
            Text(
              'Searching…',
              style: AppText.caption().copyWith(fontSize: 12.5.sp),
            ),
          ],
        ),
      );
    }

    if (suggestions.isEmpty) {
      // Don't show "no results" until we've actually completed a query
      // — avoids flashing it on the first focus before any typing.
      if (!hasSearched) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 16.w),
        child: Center(
          child: Text(
            'No matching places',
            style: AppText.caption().copyWith(fontSize: 12.5.sp),
          ),
        ),
      );
    }

    // shrinkWrap + ClampingScrollPhysics is what makes the list both
    // size itself to its content (so 1 result doesn't render a 240h
    // void) AND scroll when the content overflows the ConstrainedBox
    // maxHeight. ListView's default NeverScrollable behaviour under
    // shrinkWrap is what blocks scroll without the explicit physics.
    // Results are a list, not a stack of cards: one 1px rule between rows,
    // inset past the icon column so the rule starts at the text.
    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      itemCount: suggestions.length,
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      separatorBuilder: (_, __) => Padding(
        padding: EdgeInsets.only(left: 48.w, right: 16.w),
        child: const AppDivider(),
      ),
      itemBuilder: (context, i) {
        final s = suggestions[i];
        return InkWell(
          onTap: () => onTap(s),
          // Slight pressed-state colour gives feedback even though the
          // Material above already does the ink ripple.
          highlightColor: Consonants.indigoWash,
          splashColor: Consonants.indigoWash,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 11.h),
            child: Row(
              children: [
                Container(
                  width: 26.w,
                  height: 26.w,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Consonants.chipBg,
                  ),
                  child: Icon(
                    Icons.place_outlined,
                    size: 15.sp,
                    color: Consonants.iconInk,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.rowLabel(color: Consonants.headingInk)
                            .copyWith(
                                fontSize: 14.sp, fontWeight: FontWeight.w600),
                      ),
                      if (s.formatted.isNotEmpty) ...[
                        SizedBox(height: 2.h),
                        Text(
                          s.formatted,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption().copyWith(fontSize: 11.5.sp),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
