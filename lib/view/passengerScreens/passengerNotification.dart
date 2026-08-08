import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ride_sharing/widgets/custom/acceptJoinDialog.dart';
import 'package:ride_sharing/model/notificationModels.dart';
import 'package:ride_sharing/provider/notificationProvider.dart';
import 'package:ride_sharing/provider/providers.dart';
import 'package:ride_sharing/provider/rideDetailsProvider.dart';
import 'package:ride_sharing/provider/passengerActiveRideProvider.dart';
import 'package:ride_sharing/view/bottomNavbar.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
import 'package:ride_sharing/widgets/custom/appComponents.dart';
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

enum _NotifType { request, driverOffer, trip, rating, system }

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
      type == _NotifType.request &&
      rideId != null &&
      requestId != null &&
      requestId!.isNotEmpty &&
      subjectUserId != null;

  /// True for a driver's offer to drive — renders the accept/decline card.
  /// [requestId] carries the offer id.
  bool get isDriverOffer =>
      type == _NotifType.driverOffer &&
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
          NotifType.driverOffer => _NotifType.driverOffer,
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
    // Fare-aware confirm: show the host what accepting does to their fare
    // (and what the requester pays) BEFORE committing.
    if (accept) {
      final ok = await confirmAcceptJoin(context, ref,
          rideId: n.rideId!,
          requestId: n.requestId!,
          requesterName: n.subjectName ?? 'this rider');
      if (!ok) return;
    }
    try {
      final service = ref.read(rideServiceProvider);
      if (accept) {
        await service.acceptJoinRequest(n.rideId!, n.requestId!);
      } else {
        await service.declineJoinRequest(n.rideId!, n.requestId!);
      }
      // Accepting added the requester to the ride (and decremented a seat);
      // the cached ride details + the host's active-ride feed are now stale.
      // Without this, opening the ride still shows "No one has joined yet".
      ref.invalidate(rideDetailsProvider(n.rideId!));
      ref.invalidate(passengerActiveRideProvider);
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

  /// Accept or decline a driver's offer from the notification card. Accepting
  /// assigns that driver and moves the ride to ACCEPTED; the host's cached
  /// ride details + active-ride feed are refreshed so the driver shows up.
  Future<void> _respondToDriverOffer(_NotificationItem n, bool accept) async {
    if (n.rideId == null || n.requestId == null) return;
    try {
      final service = ref.read(rideServiceProvider);
      if (accept) {
        await service.acceptDriverOffer(n.rideId!, n.requestId!);
      } else {
        await service.declineDriverOffer(n.rideId!, n.requestId!);
      }
      ref.invalidate(rideDetailsProvider(n.rideId!));
      ref.invalidate(passengerActiveRideProvider);
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
            accept ? 'Driver assigned to your ride' : 'Driver declined'));
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
          backgroundColor: Consonants.headingInk,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Consonants.rCard.r),
          ),
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
          padding: EdgeInsets.fromLTRB(
              Consonants.gutter.w, 16.h, Consonants.gutter.w, 16.h),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SheetHeader(title: n.title),
                SizedBox(height: 4.h),
                Text(
                  n.timeAgo,
                  style: AppText.caption().copyWith(fontSize: 12.5.sp),
                ),
                SizedBox(height: 16.h),
                const AppDivider(),
                _sheetAction(
                  icon: n.unread
                      ? Icons.mark_email_read_outlined
                      : Icons.mark_email_unread_outlined,
                  label: n.unread ? "Mark as read" : "Mark as unread",
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _toggleRead(n.id);
                  },
                ),
                const AppDivider(),
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: Consonants.rowVertical.h),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20.sp,
              color: destructive ? Consonants.danger : Consonants.iconInk,
            ),
            SizedBox(width: 14.w),
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
            SizedBox(height: 20.h),
            Expanded(
              child: RefreshIndicator(
                color: Consonants.indigo,
                backgroundColor: Consonants.surface,
                onRefresh: _onRefresh,
                child: _loading && _items.isEmpty
                    ? _statusList(const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Consonants.indigo,
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
                        padding: EdgeInsets.fromLTRB(
                          Consonants.gutter.w,
                          0,
                          Consonants.gutter.w,
                          32.h,
                        ),
                        children: [
                          if (today.isNotEmpty) ...[
                            const AppSectionHeading(label: "Today"),
                            ..._group(today),
                            SizedBox(height: 30.h),
                          ],
                          if (earlier.isNotEmpty) ...[
                            const AppSectionHeading(label: "Earlier"),
                            ..._group(earlier),
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

  /// Lays a group out as a list: rows separated by a 1px rule, with the
  /// richer accept/decline cards breathing on their own.
  List<Widget> _group(List<_NotificationItem> items) {
    final out = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      final actionable = items[i].isJoinRequest || items[i].isDriverOffer;
      if (actionable) out.add(SizedBox(height: Consonants.gapTiles.h));
      out.add(_notificationCard(items[i]));
      if (i == items.length - 1) continue;
      final nextActionable =
          items[i + 1].isJoinRequest || items[i + 1].isDriverOffer;
      out.add(actionable || nextActionable
          ? SizedBox(height: Consonants.gapTiles.h)
          : const AppDivider());
    }
    return out;
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
              width: 68.w,
              height: 68.w,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Consonants.dangerWash,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_outlined,
                size: 30.sp,
                color: Consonants.danger,
              ),
            ),
            SizedBox(height: 18.h),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppText.sectionHeading().copyWith(fontSize: 17.sp),
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
      subtitle: unreadCount > 0 ? "$unreadCount unread" : null,
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
                  Icon(
                    Icons.done_all_rounded,
                    size: 16.sp,
                    color: Consonants.iconInk,
                  ),
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

  // ─── Rows ────────────────────────────────────────────────

  /// A join request or driver offer carries a decision, so it renders as a
  /// card with inline actions. Everything else is a plain row.
  Widget _notificationCard(_NotificationItem n) {
    final actionable = n.isJoinRequest || n.isDriverOffer;
    return Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 18.w),
        decoration: BoxDecoration(
          color: Consonants.danger,
          borderRadius: BorderRadius.circular(Consonants.rCard.r),
        ),
        child: Row(
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
      child: actionable ? _actionableCard(n) : _plainRow(n),
    );
  }

  Widget _plainRow(_NotificationItem n) {
    final visuals = _visualsFor(n.type);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openNotification(n),
        onLongPress: () => _showActionSheet(n),
        splashColor: Consonants.violet.withValues(alpha: 0.06),
        highlightColor: Consonants.violet.withValues(alpha: 0.04),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: Consonants.rowVertical.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _typeIcon(visuals),
              SizedBox(width: 14.w),
              Expanded(child: _rowBody(n)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionableCard(_NotificationItem n) {
    final visuals = _visualsFor(n.type);
    final handled = n.handledLabel;
    return AppCard(
      onTap: () => _openNotification(n),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _typeIcon(visuals),
              SizedBox(width: 14.w),
              Expanded(child: _rowBody(n)),
            ],
          ),
          if (n.pickup != null && n.drop != null) ...[
            SizedBox(height: 14.h),
            _routeLine(Icons.trip_origin, n.pickup!),
            SizedBox(height: 6.h),
            _routeLine(Icons.place_outlined, n.drop!),
          ],
          SizedBox(height: 16.h),
          if (handled != null)
            Text(
              handled,
              style: AppText.rowLabel(
                color: handled == 'Accepted'
                    ? Consonants.credit
                    : Consonants.textMuted,
              ).copyWith(fontSize: 14.sp),
            )
          else
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: "Decline",
                    kind: AppButtonKind.secondary,
                    onPressed: () => n.isDriverOffer
                        ? _respondToDriverOffer(n, false)
                        : _respondToJoinRequest(n, false),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: AppButton(
                    label: "Accept",
                    onPressed: () => n.isDriverOffer
                        ? _respondToDriverOffer(n, true)
                        : _respondToJoinRequest(n, true),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _typeIcon(_NotifVisuals visuals) {
    return Container(
      width: 44.w,
      height: 44.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: visuals.bg, shape: BoxShape.circle),
      child: Icon(visuals.icon, size: 20.sp, color: visuals.fg),
    );
  }

  /// Title + message + timestamp. Unread is carried by the violet dot and a
  /// heavier title, not by a background tint.
  Widget _rowBody(_NotificationItem n) {
    return Column(
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
                  fontWeight: n.unread ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
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
                  : const SizedBox.shrink(key: ValueKey("nodot")),
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
        Text(n.timeAgo, style: AppText.caption().copyWith(fontSize: 12.sp)),
      ],
    );
  }

  Widget _routeLine(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 15.sp, color: Consonants.iconInk),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.rowLabel().copyWith(fontSize: 14.sp),
          ),
        ),
      ],
    );
  }

  _NotifVisuals _visualsFor(_NotifType type) {
    switch (type) {
      case _NotifType.request:
        return const _NotifVisuals(
          icon: Icons.person_add_alt_outlined,
          fg: Consonants.iconInk,
          bg: Consonants.indigoWash,
        );
      case _NotifType.driverOffer:
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
        SizedBox(height: 70.h),
        Center(
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
                  color: Consonants.indigo,
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                "No notifications yet",
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
