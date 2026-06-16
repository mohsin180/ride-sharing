import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ride_sharing/model/notificationModels.dart';
import 'package:ride_sharing/provider/notificationProvider.dart';
import 'package:ride_sharing/provider/providers.dart';
import 'package:ride_sharing/view/bottomNavbar.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';
import 'package:ride_sharing/widgets/custom/ratingSheet.dart';

/// Passenger notifications screen. Mirrors [Drivernotification] in look
/// and behaviour but the seed copy is from the passenger's POV — driver
/// assignments, ride completions, rating prompts and promo codes
/// instead of new ride requests, earnings and verification updates.
///
/// UX behaviors:
///   • Tap a card        → mark it read; ride-assignment items also
///                         switch the navbar to "Your Ride".
///   • Long-press a card → opens a bottom-sheet menu (read toggle, delete).
///   • Swipe left        → dismiss the card; a snackbar offers undo.
///   • Pull to refresh   → simulates fetching newer notifications.
///   • Settings icon     → placeholder hook for notification preferences.
class Passengernotification extends ConsumerStatefulWidget {
  const Passengernotification({super.key});

  @override
  ConsumerState<Passengernotification> createState() =>
      _PassengernotificationState();
}

enum _NotifType { request, trip, rating, system }

enum _Filter { all, unread, trips }

class _NotificationItem {
  final String id;
  final _NotifType type;
  final String title;
  final String message;
  final String timeAgo;
  final bool isToday;
  final bool unread;
  final String? rideId;
  final String? subjectUserId;
  final String? subjectName;
  final double? subjectRating;
  final String? requestId;
  final String? pickup;
  final String? drop;

  /// Once the host responds, the inline accept/decline buttons are replaced
  /// by this label ("Accepted" / "Declined"). Null while still actionable.
  final String? handledLabel;

  const _NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timeAgo,
    required this.isToday,
    required this.unread,
    this.rideId,
    this.subjectUserId,
    this.subjectName,
    this.subjectRating,
    this.requestId,
    this.pickup,
    this.drop,
    this.handledLabel,
  });

  /// True when tapping should open a rating sheet for a co-passenger who left.
  bool get isRatePrompt =>
      type == _NotifType.rating &&
      rideId != null &&
      subjectUserId != null &&
      subjectUserId!.isNotEmpty;

  /// True for a host's join request — renders the accept/decline card.
  bool get isJoinRequest =>
      rideId != null &&
      requestId != null &&
      requestId!.isNotEmpty &&
      subjectUserId != null;

  _NotificationItem copyWith({bool? unread, String? handledLabel}) =>
      _NotificationItem(
        id: id,
        type: type,
        title: title,
        message: message,
        timeAgo: timeAgo,
        isToday: isToday,
        unread: unread ?? this.unread,
        rideId: rideId,
        subjectUserId: subjectUserId,
        subjectName: subjectName,
        subjectRating: subjectRating,
        requestId: requestId,
        pickup: pickup,
        drop: drop,
        handledLabel: handledLabel ?? this.handledLabel,
      );
}

class _PassengernotificationState extends ConsumerState<Passengernotification> {
  _Filter _filter = _Filter.all;
  List<_NotificationItem> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Fetch real notifications. On first open also clears the home-screen
  /// badge (mark-all-read server-side) while keeping the unread styling
  /// for this view so the rider can still see what's new.
  Future<void> _load({bool clearBadge = true}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref.read(notificationServiceProvider).getNotifications();
      if (!mounted) return;
      setState(() {
        _items = list.map(_fromServer).toList();
        _loading = false;
      });
      if (clearBadge && list.any((n) => !n.read)) {
        await ref.read(notificationServiceProvider).markAllRead();
        ref.invalidate(unreadCountProvider);
        ref.invalidate(notificationsProvider);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ErrorHandler.message(e);
      });
    }
  }

  _NotificationItem _fromServer(AppNotification n) => _NotificationItem(
        id: n.id,
        type: switch (n.type) {
          NotifType.request => _NotifType.request,
          NotifType.trip => _NotifType.trip,
          NotifType.rating => _NotifType.rating,
          NotifType.system => _NotifType.system,
        },
        title: n.title,
        message: n.body,
        timeAgo: n.relativeTime,
        isToday: n.isToday,
        unread: !n.read,
        rideId: n.rideId,
        subjectUserId: n.subjectUserId,
        subjectName: n.subjectName,
        subjectRating: n.subjectRating,
        requestId: n.requestId,
        pickup: n.pickup,
        drop: n.drop,
      );

  /// Accept or decline a host's join request from the notification card.
  Future<void> _respondToJoinRequest(_NotificationItem n, bool accept) async {
    if (n.rideId == null || n.requestId == null) return;
    try {
      final service = ref.read(rideServiceProvider);
      if (accept) {
        await service.acceptJoinRequest(n.rideId!, n.requestId!);
      } else {
        await service.declineJoinRequest(n.rideId!, n.requestId!);
      }
      if (!mounted) return;
      setState(() {
        _items = _items
            .map((it) => it.id == n.id
                ? it.copyWith(handledLabel: accept ? 'Accepted' : 'Declined')
                : it)
            .toList();
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(CustomWidgets.customSuccessSnackBar(
            accept ? 'Passenger added to your ride' : 'Request declined'));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(CustomWidgets.customErrorSnackBar(ErrorHandler.message(e)));
    }
  }

  // ─── State mutations ─────────────────────────────────────

  void _markAllRead() {
    setState(() {
      _items = _items.map((n) => n.copyWith(unread: false)).toList();
    });
    ref.read(notificationServiceProvider).markAllRead();
    ref.invalidate(unreadCountProvider);
  }

  void _toggleRead(String id) {
    final wasUnread = _items.any((n) => n.id == id && n.unread);
    setState(() {
      _items = _items
          .map((n) => n.id == id ? n.copyWith(unread: !n.unread) : n)
          .toList();
    });
    if (wasUnread) {
      ref.read(notificationServiceProvider).markAsRead(id);
      ref.invalidate(unreadCountProvider);
    }
  }

  /// Opens the notification — marks it read and, for driver-assignment
  /// items, pops back to the navbar and switches to the "Your Ride" tab
  /// so the passenger lands straight on the active-ride view.
  Future<void> _openNotification(_NotificationItem n) async {
    if (n.unread) {
      ref.read(notificationServiceProvider).markAsRead(n.id);
      ref.invalidate(unreadCountProvider);
    }
    setState(() {
      _items = _items
          .map((it) => it.id == n.id ? it.copyWith(unread: false) : it)
          .toList();
    });

    if (n.type == _NotifType.request) {
      ref.read(bottomNavIndexProvider.notifier).select(2);
      context.pop();
      return;
    }

    // A co-passenger left at their stop — open the rating sheet for them.
    if (n.isRatePrompt) {
      final name = (n.subjectName ?? '').trim().isEmpty
          ? 'co-passenger'
          : n.subjectName!.trim();
      final stars = await showRatingSheet(
        context: context,
        title: 'Rate $name',
        subtitle: 'How was riding with them?',
        avatarInitial: name[0].toUpperCase(),
      );
      if (stars == null || !mounted) return;
      try {
        await ref
            .read(rideServiceProvider)
            .rateCoPassenger(n.rideId!, n.subjectUserId!, stars);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(CustomWidgets.customSuccessSnackBar("Rating submitted"));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(CustomWidgets.customErrorSnackBar(ErrorHandler.message(e)));
      }
    }
  }

  void _deleteNotification(_NotificationItem n) {
    final originalIndex = _items.indexWhere((it) => it.id == n.id);
    if (originalIndex < 0) return;

    setState(() {
      _items = List.of(_items)..removeAt(originalIndex);
    });

    // Commit the delete to the backend after the undo window; UNDO cancels it.
    final commit = Timer(const Duration(seconds: 4), () async {
      try {
        await ref.read(notificationServiceProvider).deleteNotification(n.id);
        ref.invalidate(unreadCountProvider);
      } catch (_) {
        // Network hiccup — a later refresh reconciles the list.
      }
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: Consonants.boldTextColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              Icon(Icons.delete_outline_rounded,
                  size: 16.sp, color: Consonants.whiteColor),
              SizedBox(width: 8.w),
              Expanded(
                child: CustomWidgets.customText(
                  "Notification removed",
                  11.sp,
                  Consonants.whiteColor,
                  FontWeight.w600,
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: "UNDO",
            textColor: Consonants.primaryColor,
            onPressed: () {
              commit.cancel();
              setState(() {
                _items = List.of(_items)..insert(originalIndex, n);
              });
            },
          ),
        ),
      );
  }

  Future<void> _onRefresh() async {
    // Don't re-clear the badge on a manual refresh.
    await _load(clearBadge: false);
  }

  // ─── Long-press action sheet ─────────────────────────────

  void _showActionSheet(_NotificationItem n) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.40),
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: Consonants.whiteColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 10.h),
                Container(
                  width: 44.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Consonants.lightGreyColor,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 14.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomWidgets.customText(
                              n.title,
                              13.sp,
                              Consonants.boldTextColor,
                              FontWeight.w800,
                            ),
                            SizedBox(height: 3.h),
                            CustomWidgets.customText(
                              n.timeAgo,
                              10.sp,
                              Consonants.greyColor,
                              FontWeight.w500,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14.h),
                Container(height: 1, color: Consonants.lightGreyColor),
                _sheetAction(
                  icon: n.unread
                      ? Icons.mark_email_read_rounded
                      : Icons.mark_email_unread_rounded,
                  label: n.unread ? "Mark as read" : "Mark as unread",
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _toggleRead(n.id);
                  },
                ),
                _sheetAction(
                  icon: Icons.delete_outline_rounded,
                  label: "Delete",
                  destructive: true,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _deleteNotification(n);
                  },
                ),
                SizedBox(height: 8.h),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sheetAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final color =
        destructive ? const Color(0xffEF4444) : Consonants.boldTextColor;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        child: Row(
          children: [
            Icon(icon, size: 18.sp, color: color),
            SizedBox(width: 14.w),
            CustomWidgets.customText(
              label,
              12.sp,
              color,
              FontWeight.w700,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _applyFilter(_items);
    final unreadCount = _items.where((n) => n.unread).length;
    final today = filtered.where((n) => n.isToday).toList();
    final earlier = filtered.where((n) => !n.isToday).toList();

    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(unreadCount),
            SizedBox(height: 12.h),
            _filterPills(),
            SizedBox(height: 14.h),
            Expanded(
              child: RefreshIndicator(
                color: Consonants.primaryColor,
                backgroundColor: Consonants.whiteColor,
                onRefresh: _onRefresh,
                child: _loading && _items.isEmpty
                    ? _statusList(const Center(
                        child: CircularProgressIndicator(
                          color: Consonants.primaryColor,
                        ),
                      ))
                    : _error != null && _items.isEmpty
                        ? _statusList(_errorState(_error!))
                        : filtered.isEmpty
                    ? _emptyState()
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: EdgeInsets.only(bottom: 24.h),
                        children: [
                          if (today.isNotEmpty) ...[
                            _sectionLabel("Today"),
                            SizedBox(height: 10.h),
                            for (int i = 0; i < today.length; i++) ...[
                              _notificationCard(today[i]),
                              if (i != today.length - 1)
                                SizedBox(height: 10.h),
                            ],
                            SizedBox(height: 22.h),
                          ],
                          if (earlier.isNotEmpty) ...[
                            _sectionLabel("Earlier"),
                            SizedBox(height: 10.h),
                            for (int i = 0; i < earlier.length; i++) ...[
                              _notificationCard(earlier[i]),
                              if (i != earlier.length - 1)
                                SizedBox(height: 10.h),
                            ],
                          ],
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Wraps a status widget (spinner/error) in a scroll view so the
  /// RefreshIndicator can still be pulled while it's shown.
  Widget _statusList(Widget child) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [SizedBox(height: 160.h), child],
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            SizedBox(height: 6.h),
            CustomWidgets.customText(
              "Pull down to retry",
              10.sp,
              Consonants.greyColor,
              FontWeight.w500,
            ),
          ],
        ),
      ),
    );
  }

  List<_NotificationItem> _applyFilter(List<_NotificationItem> all) {
    switch (_filter) {
      case _Filter.all:
        return all;
      case _Filter.unread:
        return all.where((n) => n.unread).toList();
      case _Filter.trips:
        return all
            .where((n) =>
                n.type == _NotifType.trip || n.type == _NotifType.request)
            .toList();
    }
  }

  // ─── Top bar ─────────────────────────────────────────────

  Widget _topBar(int unreadCount) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14.w, 10.h, 16.w, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40.w,
              height: 40.w,
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
              child: Icon(
                Icons.arrow_back_rounded,
                size: 18.sp,
                color: Consonants.boldTextColor,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomWidgets.customText(
                  "Notifications",
                  18.sp,
                  Consonants.boldTextColor,
                  FontWeight.w800,
                ),
                SizedBox(height: 2.h),
                CustomWidgets.customText(
                  unreadCount > 0
                      ? "$unreadCount unread"
                      : "All caught up",
                  10.sp,
                  Consonants.greyColor,
                  FontWeight.w500,
                ),
              ],
            ),
          ),
          if (unreadCount > 0) ...[
            GestureDetector(
              onTap: _markAllRead,
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Consonants.lightBlueColor,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  children: [
                    Icon(Icons.done_all_rounded,
                        size: 14.sp, color: Consonants.primaryColor),
                    SizedBox(width: 5.w),
                    CustomWidgets.customText(
                      "Mark read",
                      10.sp,
                      Consonants.primaryColor,
                      FontWeight.w800,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Filter pills ────────────────────────────────────────

  Widget _filterPills() {
    return SizedBox(
      height: 36.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        children: [
          _pill("All", _Filter.all, count: _items.length),
          SizedBox(width: 8.w),
          _pill("Unread", _Filter.unread,
              count: _items.where((n) => n.unread).length),
          SizedBox(width: 8.w),
          _pill("Trips", _Filter.trips,
              count: _items
                  .where((n) =>
                      n.type == _NotifType.trip ||
                      n.type == _NotifType.request)
                  .length),
        ],
      ),
    );
  }

  Widget _pill(String label, _Filter value, {int count = 0}) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
                )
              : null,
          color: selected ? null : Consonants.whiteColor,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: selected
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
            CustomWidgets.customText(
              label,
              11.sp,
              selected ? Consonants.whiteColor : Consonants.boldTextColor,
              FontWeight.w700,
            ),
            if (count > 0) ...[
              SizedBox(width: 6.w),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.30)
                      : Consonants.lightBlueColor,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: CustomWidgets.customText(
                  "$count",
                  9.sp,
                  selected ? Consonants.whiteColor : Consonants.primaryColor,
                  FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Section label ───────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Row(
        children: [
          CustomWidgets.customText(
            text.toUpperCase(),
            10.sp,
            Consonants.greyColor,
            FontWeight.w700,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Container(
              height: 1,
              color: Consonants.lightGreyColor,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Join-request card (host: accept / decline) ─────────

  Widget _joinRequestCard(_NotificationItem n) {
    final name = (n.subjectName ?? '').trim().isEmpty
        ? 'Passenger'
        : n.subjectName!.trim();
    final ratingLabel = (n.subjectRating != null && n.subjectRating! > 0)
        ? n.subjectRating!.toStringAsFixed(1)
        : '—';
    final handled = n.handledLabel;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Consonants.whiteColor,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: Consonants.primaryColor.withValues(alpha: 0.25),
            width: 1.2,
          ),
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
                Container(
                  width: 44.w,
                  height: 44.w,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
                    ),
                  ),
                  child: Text(
                    name[0].toUpperCase(),
                    style: TextStyle(
                      color: Consonants.whiteColor,
                      fontSize: 18.sp,
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
                      CustomWidgets.customText(
                        name,
                        14.sp,
                        Consonants.boldTextColor,
                        FontWeight.w800,
                        maxLines: 1,
                      ),
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              size: 12.sp, color: const Color(0xffF5B800)),
                          SizedBox(width: 3.w),
                          CustomWidgets.customText(
                            "$ratingLabel · wants to join",
                            11.sp,
                            Consonants.greyColor,
                            FontWeight.w600,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                CustomWidgets.customText(
                  n.timeAgo,
                  9.sp,
                  Consonants.greyColor,
                  FontWeight.w500,
                ),
              ],
            ),
            SizedBox(height: 14.h),
            _joinRouteRow(
              Icons.my_location_rounded,
              const Color(0xff2196F3),
              "Pickup",
              n.pickup ?? "—",
            ),
            SizedBox(height: 8.h),
            _joinRouteRow(
              Icons.location_on_rounded,
              const Color(0xffEF4444),
              "Drop-off",
              n.drop ?? "—",
            ),
            SizedBox(height: 16.h),
            if (handled != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Consonants.lightBlueColor,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: CustomWidgets.customText(
                  handled,
                  12.sp,
                  Consonants.primaryColor,
                  FontWeight.w800,
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _respondToJoinRequest(n, false),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 13.h),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Consonants.whiteColor,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: const Color(0xffEF4444),
                            width: 1.5,
                          ),
                        ),
                        child: CustomWidgets.customText(
                          "Decline",
                          12.sp,
                          const Color(0xffEF4444),
                          FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: () => _respondToJoinRequest(n, true),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 13.h),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
                          ),
                          borderRadius: BorderRadius.circular(12.r),
                          boxShadow: [
                            BoxShadow(
                              color: Consonants.primaryColor
                                  .withValues(alpha: 0.30),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CustomWidgets.customText(
                          "Accept",
                          12.sp,
                          Consonants.whiteColor,
                          FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _joinRouteRow(IconData icon, Color color, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14.sp, color: color),
        SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomWidgets.customText(
                label,
                9.sp,
                Consonants.greyColor,
                FontWeight.w600,
              ),
              CustomWidgets.customText(
                value,
                12.sp,
                Consonants.boldTextColor,
                FontWeight.w700,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Notification card ──────────────────────────────────

  Widget _notificationCard(_NotificationItem n) {
    // A host's join request gets its own rich card with accept/decline.
    if (n.isJoinRequest) return _joinRequestCard(n);

    final visuals = _visualsFor(n.type);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Dismissible(
        key: ValueKey(n.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: 24.w),
          decoration: BoxDecoration(
            color: const Color(0xffEF4444),
            borderRadius: BorderRadius.circular(18.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline_rounded,
                  size: 18.sp, color: Consonants.whiteColor),
              SizedBox(width: 6.w),
              CustomWidgets.customText(
                "Delete",
                11.sp,
                Consonants.whiteColor,
                FontWeight.w800,
              ),
            ],
          ),
        ),
        onDismissed: (_) => _deleteNotification(n),
        child: Material(
          color: Consonants.whiteColor,
          borderRadius: BorderRadius.circular(18.r),
          // Using BoxShadow directly is cleaner via DecoratedBox, but
          // Material's elevation hides our soft brand shadow — so we
          // wrap in a Container for shadow + border + radius.
          child: Container(
            decoration: BoxDecoration(
              color: Consonants.whiteColor,
              borderRadius: BorderRadius.circular(18.r),
              boxShadow: [
                BoxShadow(
                  color: n.unread
                      ? Consonants.primaryColor.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: n.unread
                  ? Border.all(
                      color:
                          Consonants.primaryColor.withValues(alpha: 0.18),
                      width: 1.2,
                    )
                  : null,
            ),
            child: InkWell(
              onTap: () => _openNotification(n),
              onLongPress: () => _showActionSheet(n),
              borderRadius: BorderRadius.circular(18.r),
              splashColor: Consonants.primaryColor.withValues(alpha: 0.06),
              highlightColor:
                  Consonants.primaryColor.withValues(alpha: 0.04),
              child: Padding(
                padding: EdgeInsets.all(14.w),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44.w,
                      height: 44.w,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: visuals.bg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(visuals.icon,
                          size: 20.sp, color: visuals.fg),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: CustomWidgets.customText(
                                  n.title,
                                  13.sp,
                                  Consonants.boldTextColor,
                                  FontWeight.w800,
                                ),
                              ),
                              // Animated unread dot — fades out smoothly
                              // when a notification is marked read.
                              AnimatedSwitcher(
                                duration:
                                    const Duration(milliseconds: 240),
                                transitionBuilder: (c, a) =>
                                    ScaleTransition(scale: a, child: c),
                                child: n.unread
                                    ? Padding(
                                        key: const ValueKey("dot"),
                                        padding:
                                            EdgeInsets.only(left: 6.w),
                                        child: Container(
                                          width: 7.w,
                                          height: 7.w,
                                          decoration: const BoxDecoration(
                                            color:
                                                Consonants.primaryColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(
                                        key: ValueKey("nodot")),
                              ),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            n.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: Consonants.fontFamily,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                              color: Consonants.greyColor,
                              height: 1.4,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Row(
                            children: [
                              Icon(Icons.access_time_rounded,
                                  size: 10.sp,
                                  color: Consonants.greyColor),
                              SizedBox(width: 4.w),
                              CustomWidgets.customText(
                                n.timeAgo,
                                9.sp,
                                Consonants.greyColor,
                                FontWeight.w600,
                              ),
                              if (n.type == _NotifType.request) ...[
                                SizedBox(width: 8.w),
                                Container(
                                  width: 3.w,
                                  height: 3.w,
                                  decoration: const BoxDecoration(
                                    color: Consonants.greyColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Row(
                                  children: [
                                    CustomWidgets.customText(
                                      "Tap to view",
                                      9.sp,
                                      Consonants.primaryColor,
                                      FontWeight.w800,
                                    ),
                                    SizedBox(width: 2.w),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 10.sp,
                                      color: Consonants.primaryColor,
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _NotifVisuals _visualsFor(_NotifType type) {
    switch (type) {
      case _NotifType.request:
        return _NotifVisuals(
          icon: Icons.directions_car_rounded,
          fg: Consonants.primaryColor,
          bg: Consonants.lightBlueColor,
        );
      case _NotifType.trip:
        return _NotifVisuals(
          icon: Icons.check_circle_rounded,
          fg: const Color(0xff16A34A),
          bg: Consonants.primaryGreenColor,
        );
      case _NotifType.rating:
        return _NotifVisuals(
          icon: Icons.star_rounded,
          fg: const Color(0xffF59E0B),
          bg: const Color(0xffFEF3C7),
        );
      case _NotifType.system:
        return _NotifVisuals(
          icon: Icons.info_rounded,
          fg: Consonants.greyColor,
          bg: Consonants.lightGreyColor,
        );
    }
  }

  // ─── Empty state ────────────────────────────────────────

  Widget _emptyState() {
    final (title, subtitle) = _emptyCopy();
    // Wrap in a scrollable so RefreshIndicator can still trigger a pull.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        SizedBox(height: 80.h),
        Center(
          child: Column(
            children: [
              Container(
                width: 84.w,
                height: 84.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Consonants.lightBlueColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_off_rounded,
                  size: 36.sp,
                  color: Consonants.primaryColor,
                ),
              ),
              SizedBox(height: 14.h),
              CustomWidgets.customText(
                title,
                14.sp,
                Consonants.boldTextColor,
                FontWeight.w800,
              ),
              SizedBox(height: 4.h),
              CustomWidgets.customText(
                subtitle,
                11.sp,
                Consonants.greyColor,
                FontWeight.w500,
              ),
              SizedBox(height: 14.h),
              CustomWidgets.customText(
                "Pull down to refresh",
                10.sp,
                Consonants.primaryColor,
                FontWeight.w700,
              ),
            ],
          ),
        ),
      ],
    );
  }

  (String, String) _emptyCopy() {
    switch (_filter) {
      case _Filter.unread:
        return (
          "You're all caught up",
          "No unread notifications right now",
        );
      case _Filter.trips:
        return (
          "No trip activity yet",
          "Trip and request updates will appear here",
        );
      case _Filter.all:
        return (
          "Nothing here yet",
          "We'll let you know when something arrives",
        );
    }
  }
}

class _NotifVisuals {
  final IconData icon;
  final Color fg;
  final Color bg;
  const _NotifVisuals({
    required this.icon,
    required this.fg,
    required this.bg,
  });
}
