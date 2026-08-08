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
import 'package:ride_sharing/widgets/custom/appComponents.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';
import 'package:ride_sharing/widgets/custom/ratingSheet.dart';

/// Driver notifications screen.
///
/// UX behaviors:
///   • Tap a card        → mark it read; ride-request items also pop
///                         this screen and switch the navbar to "Rides".
///   • Long-press a card → opens a bottom-sheet menu (read toggle, delete).
///   • Swipe left        → dismiss the card; a snackbar offers undo.
///   • Pull to refresh   → simulates fetching newer notifications.
///   • Settings icon     → placeholder hook for notification preferences.
class Drivernotification extends ConsumerStatefulWidget {
  const Drivernotification({super.key});

  @override
  ConsumerState<Drivernotification> createState() =>
      _DrivernotificationState();
}

enum _NotifType { request, trip, rating, system }

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
  });

  /// True when tapping should open a rating sheet for a co-passenger who left.
  bool get isRatePrompt =>
      type == _NotifType.rating &&
      rideId != null &&
      subjectUserId != null &&
      subjectUserId!.isNotEmpty;

  _NotificationItem copyWith({bool? unread}) => _NotificationItem(
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
      );
}

class _DrivernotificationState extends ConsumerState<Drivernotification> {
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
  /// for this view so the driver can still see what's new.
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
          // Drivers don't receive driver-offer cards (those go to the host);
          // map to the generic request style for safety.
          NotifType.driverOffer => _NotifType.request,
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
      );

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
    // Only a mark-as-read is persisted; toggling back to unread is local.
    if (wasUnread) {
      ref.read(notificationServiceProvider).markAsRead(id);
      ref.invalidate(unreadCountProvider);
    }
  }

  /// Opens the notification — marks it read and, if it's a ride
  /// request, pops back to the navbar and switches to the Rides tab.
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
      ref.read(bottomNavIndexProvider.notifier).select(1);
      context.pop();
      return;
    }

    // A passenger left mid-trip — let the driver rate them right away.
    if (n.isRatePrompt) {
      final name = (n.subjectName ?? '').trim().isEmpty
          ? 'passenger'
          : n.subjectName!.trim();
      final stars = await showRatingSheet(
        context: context,
        title: 'Rate $name',
        avatarInitial: name[0].toUpperCase(),
      );
      if (stars == null || !mounted) return;
      try {
        await ref
            .read(rideServiceProvider)
            .ratePassenger(n.rideId!, n.subjectUserId!, stars);
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
          backgroundColor: Consonants.headingInk,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              Icon(Icons.delete_outline_rounded,
                  size: 18.sp, color: Consonants.surface),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  "Notification removed",
                  style: AppText.rowLabel(color: Consonants.surface)
                      .copyWith(fontSize: 14.sp),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: "UNDO",
            textColor: Consonants.violet,
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
      barrierColor: Consonants.scrim,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: Consonants.surface,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(Consonants.rSheet.r)),
            boxShadow: Consonants.sheetLift,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 14.h),
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
                  child: SheetHeader(title: n.title),
                ),
                SizedBox(height: 6.h),
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      n.timeAgo,
                      style: AppText.caption().copyWith(fontSize: 12.5.sp),
                    ),
                  ),
                ),
                SizedBox(height: 18.h),
                const AppDivider(),
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
    final color = destructive ? Consonants.danger : Consonants.bodyInk;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: Consonants.gutter.w, vertical: 16.h),
        child: Row(
          children: [
            Icon(icon, size: 20.sp,
                color: destructive ? Consonants.danger : Consonants.iconInk),
            SizedBox(width: 16.w),
            Text(
              label,
              style: AppText.rowLabel(color: color).copyWith(fontSize: 16.sp),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final unreadCount = _items.where((n) => n.unread).length;
    final today = _items.where((n) => n.isToday).toList();
    final earlier = _items.where((n) => !n.isToday).toList();

    return Scaffold(
      backgroundColor: Consonants.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _topBar(unreadCount),
            SizedBox(height: 18.h),
            Expanded(
              child: RefreshIndicator(
                color: Consonants.indigo,
                backgroundColor: Consonants.surface,
                onRefresh: _onRefresh,
                child: _loading && _items.isEmpty
                    ? _statusList(const Center(
                        child: CircularProgressIndicator(
                          color: Consonants.indigo,
                          strokeWidth: 2.5,
                        ),
                      ))
                    : _error != null && _items.isEmpty
                        ? _statusList(_errorState(_error!))
                        : _items.isEmpty
                            ? _emptyState()
                            : ListView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: EdgeInsets.only(bottom: 32.h),
                        children: [
                          if (today.isNotEmpty) ...[
                            _sectionLabel("Today"),
                            SizedBox(height: 4.h),
                            for (int i = 0; i < today.length; i++) ...[
                              _notificationRow(today[i]),
                              if (i != today.length - 1) _rowDivider(),
                            ],
                            SizedBox(height: 28.h),
                          ],
                          if (earlier.isNotEmpty) ...[
                            _sectionLabel("Earlier"),
                            SizedBox(height: 4.h),
                            for (int i = 0; i < earlier.length; i++) ...[
                              _notificationRow(earlier[i]),
                              if (i != earlier.length - 1) _rowDivider(),
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
            Container(
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
            SizedBox(height: 20.h),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppText.sectionHeading().copyWith(fontSize: 18.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              "Pull down to retry",
              style: AppText.paragraph().copyWith(fontSize: 15.sp),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Top bar ─────────────────────────────────────────────

  Widget _topBar(int unreadCount) {
    return AppHeader(
      title: "Notifications",
      showBack: true,
      onBack: () => context.pop(),
      actions: [
        if (unreadCount > 0)
          GestureDetector(
            onTap: _markAllRead,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: Consonants.chipBg,
                borderRadius: BorderRadius.circular(Consonants.rPill.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.done_all_rounded,
                      size: 15.sp, color: Consonants.iconInk),
                  SizedBox(width: 6.w),
                  Text(
                    "Mark read",
                    style: AppText.navLabel(color: Consonants.iconInk)
                        .copyWith(fontSize: 12.5.sp),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ─── Section label ───────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          Consonants.gutter.w, 6.h, Consonants.gutter.w, 0),
      child: AppSectionHeading(label: text),
    );
  }

  /// The 1px rule between rows, inset past the icon column.
  Widget _rowDivider() {
    return Padding(
      padding: EdgeInsets.only(
          left: Consonants.gutter.w + 58.w, right: Consonants.gutter.w),
      child: const AppDivider(),
    );
  }

  // ─── Notification card ──────────────────────────────────

  Widget _notificationRow(_NotificationItem n) {
    final visuals = _visualsFor(n.type);

    return Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: Consonants.gutter.w),
        color: Consonants.danger,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline_rounded,
                size: 19.sp, color: Consonants.surface),
            SizedBox(width: 8.w),
            Text(
              "Delete",
              style: AppText.navLabel(color: Consonants.surface)
                  .copyWith(fontSize: 13.sp),
            ),
          ],
        ),
      ),
      onDismissed: (_) => _deleteNotification(n),
      // A notification is a row in a list, not a card: it divides with a
      // rule and leans on weight — not a border — to read as unread.
      child: Material(
        color: Consonants.canvas,
        child: InkWell(
          onTap: () => _openNotification(n),
          onLongPress: () => _showActionSheet(n),
          splashColor: Consonants.violet.withValues(alpha: 0.06),
          highlightColor: Consonants.violet.withValues(alpha: 0.04),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Consonants.gutter.w,
              vertical: Consonants.rowVertical.h,
            ),
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
                  child: Icon(visuals.icon, size: 20.sp, color: visuals.fg),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              n.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.rowLabel().copyWith(
                                fontSize: 16.sp,
                                fontWeight: n.unread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          // Animated unread dot — fades out smoothly
                          // when a notification is marked read.
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 240),
                            transitionBuilder: (c, a) =>
                                ScaleTransition(scale: a, child: c),
                            child: n.unread
                                ? Padding(
                                    key: const ValueKey("dot"),
                                    padding: EdgeInsets.only(left: 8.w),
                                    child: Container(
                                      width: 7.w,
                                      height: 7.w,
                                      decoration: const BoxDecoration(
                                        color: Consonants.violet,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(
                                    key: ValueKey("nodot")),
                          ),
                        ],
                      ),
                      SizedBox(height: 5.h),
                      Text(
                        n.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.paragraph().copyWith(fontSize: 14.sp),
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Text(
                            n.timeAgo,
                            style:
                                AppText.caption().copyWith(fontSize: 12.sp),
                          ),
                          if (n.type == _NotifType.request) ...[
                            SizedBox(width: 8.w),
                            Icon(Icons.arrow_forward_rounded,
                                size: 12.sp, color: Consonants.indigo),
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
    );
  }

  _NotifVisuals _visualsFor(_NotifType type) {
    switch (type) {
      case _NotifType.request:
        return const _NotifVisuals(
          icon: Icons.directions_car_outlined,
          fg: Consonants.iconInk,
          bg: Consonants.indigoWash,
        );
      case _NotifType.trip:
        return const _NotifVisuals(
          icon: Icons.check_circle_outline_rounded,
          fg: Consonants.credit,
          bg: Consonants.creditWash,
        );
      case _NotifType.rating:
        return const _NotifVisuals(
          icon: Icons.star_outline_rounded,
          fg: Consonants.iconInk,
          bg: Consonants.indigoWash,
        );
      case _NotifType.system:
        return const _NotifVisuals(
          icon: Icons.info_outline_rounded,
          fg: Consonants.textMuted,
          bg: Consonants.chipBg,
        );
    }
  }

  // ─── Empty state ────────────────────────────────────────

  Widget _emptyState() {
    // Wrap in a scrollable so RefreshIndicator can still trigger a pull.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        SizedBox(height: 80.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
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
                  Icons.notifications_none_rounded,
                  size: 34.sp,
                  color: Consonants.iconInk,
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                "Nothing here yet",
                textAlign: TextAlign.center,
                style: AppText.sectionHeading().copyWith(fontSize: 18.sp),
              ),
            ],
          ),
        ),
      ],
    );
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
