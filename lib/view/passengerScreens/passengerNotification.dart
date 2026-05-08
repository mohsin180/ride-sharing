import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ride_sharing/view/bottomNavbar.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

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

enum _NotifType { request, trip, earnings, rating, system }

enum _Filter { all, unread, trips, earnings }

class _NotificationItem {
  final String id;
  final _NotifType type;
  final String title;
  final String message;
  final String timeAgo;
  final bool isToday;
  final bool unread;

  const _NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timeAgo,
    required this.isToday,
    required this.unread,
  });

  _NotificationItem copyWith({bool? unread}) => _NotificationItem(
        id: id,
        type: type,
        title: title,
        message: message,
        timeAgo: timeAgo,
        isToday: isToday,
        unread: unread ?? this.unread,
      );
}

class _PassengernotificationState extends ConsumerState<Passengernotification> {
  _Filter _filter = _Filter.all;
  late List<_NotificationItem> _items;

  @override
  void initState() {
    super.initState();
    _items = const [
      _NotificationItem(
        id: "n1",
        type: _NotifType.request,
        title: "Driver on the way",
        message:
            "Your driver is heading to Hostel City, Block B • ETA 4 min",
        timeAgo: "5 min ago",
        isToday: true,
        unread: true,
      ),
      _NotificationItem(
        id: "n2",
        type: _NotifType.trip,
        title: "Trip completed",
        message: "You arrived at Taramri Chowk • Rs 250 charged",
        timeAgo: "1 hour ago",
        isToday: true,
        unread: true,
      ),
      _NotificationItem(
        id: "n3",
        type: _NotifType.rating,
        title: "Rate your driver",
        message: "How was your ride? Tap to leave a rating",
        timeAgo: "3 hours ago",
        isToday: true,
        unread: false,
      ),
      _NotificationItem(
        id: "n4",
        type: _NotifType.earnings,
        title: "Promo unlocked",
        message: "Rs 100 off your next ride — code SAFE100",
        timeAgo: "Yesterday",
        isToday: false,
        unread: false,
      ),
      _NotificationItem(
        id: "n5",
        type: _NotifType.request,
        title: "Driver matched",
        message: "Driver assigned for your Bahria Phase 7 booking",
        timeAgo: "Yesterday",
        isToday: false,
        unread: false,
      ),
      _NotificationItem(
        id: "n6",
        type: _NotifType.system,
        title: "Account verified",
        message: "Your phone number has been successfully verified",
        timeAgo: "2 days ago",
        isToday: false,
        unread: false,
      ),
    ];
  }

  // ─── State mutations ─────────────────────────────────────

  void _markAllRead() {
    setState(() {
      _items = _items.map((n) => n.copyWith(unread: false)).toList();
    });
  }

  void _toggleRead(String id) {
    setState(() {
      _items = _items
          .map((n) => n.id == id ? n.copyWith(unread: !n.unread) : n)
          .toList();
    });
  }

  /// Opens the notification — marks it read and, for driver-assignment
  /// items, pops back to the navbar and switches to the "Your Ride" tab
  /// so the passenger lands straight on the active-ride view.
  void _openNotification(_NotificationItem n) {
    setState(() {
      _items = _items
          .map((it) => it.id == n.id ? it.copyWith(unread: false) : it)
          .toList();
    });

    if (n.type == _NotifType.request) {
      ref.read(bottomNavIndexProvider.notifier).select(2);
      context.pop();
    }
  }

  void _deleteNotification(_NotificationItem n) {
    final originalIndex = _items.indexWhere((it) => it.id == n.id);
    if (originalIndex < 0) return;

    setState(() {
      _items = List.of(_items)..removeAt(originalIndex);
    });

    final messenger = ScaffoldMessenger.of(context)
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
              setState(() {
                _items = List.of(_items)..insert(originalIndex, n);
              });
            },
          ),
        ),
      );
    // Reference messenger so the lint doesn't complain about the cascade.
    messenger.toString();
  }

  Future<void> _onRefresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _items = [
        const _NotificationItem(
          id: "n_new",
          type: _NotifType.request,
          title: "Driver on the way",
          message: "Your driver is approaching F-10 Markaz • ETA 3 min",
          timeAgo: "Just now",
          isToday: true,
          unread: true,
        ),
        ..._items,
      ];
    });
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
                child: filtered.isEmpty
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
      case _Filter.earnings:
        return all.where((n) => n.type == _NotifType.earnings).toList();
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
            SizedBox(width: 8.w),
          ],
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  CustomWidgets.customSuccessSnackBar(
                    "Notification settings coming soon",
                  ),
                );
            },
            child: Container(
              width: 36.w,
              height: 36.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Consonants.whiteColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.tune_rounded,
                  size: 16.sp, color: Consonants.boldTextColor),
            ),
          ),
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
          SizedBox(width: 8.w),
          _pill("Promos", _Filter.earnings,
              count: _items
                  .where((n) => n.type == _NotifType.earnings)
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

  // ─── Notification card ──────────────────────────────────

  Widget _notificationCard(_NotificationItem n) {
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
      case _NotifType.earnings:
        return _NotifVisuals(
          icon: Icons.emoji_events_rounded,
          fg: const Color(0xffB45309),
          bg: const Color(0xffFEF3C7),
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
      case _Filter.earnings:
        return (
          "No promos right now",
          "Discount codes and offers will land here",
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
