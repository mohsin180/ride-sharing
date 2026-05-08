import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ride_sharing/view/driverScreens/driverChatDetail.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

/// Driver group-chat list. Every conversation is a shared-ride group
/// (driver + passengers), never 1:1.
///
/// UX behaviors:
///   • Search        — live-filters by group name and last message.
///   • Filter pills  — All / Unread / Active rides, with live counts.
///   • Pinned        — pinned chats float to the top in a labeled section.
///   • Tap chat      — placeholder snackbar (chat-detail screen is TBD).
///   • Long-press    — bottom-sheet menu: pin, mute, mark unread, delete.
///   • Swipe left    — archive; snackbar offers undo.
///   • Pull to refresh — simulates fetching new messages.
///   • Compose icon  — placeholder for "start a new group" flow.
class Drivermessages extends StatefulWidget {
  const Drivermessages({super.key});

  @override
  State<Drivermessages> createState() => _DrivermessagesState();
}

enum _ChatFilter { all, unread, active }

class _ChatMember {
  final String initial;
  final Color color;
  const _ChatMember({required this.initial, required this.color});
}

class _ChatGroup {
  final String id;
  final String name;
  final List<_ChatMember> members;
  final String lastSender;
  final String lastMessage;
  final String timeAgo;
  final int unread;
  final bool fromYou;
  final bool readByOthers;
  final bool isActive;
  final bool typing;
  final bool muted;
  final bool pinned;

  const _ChatGroup({
    required this.id,
    required this.name,
    required this.members,
    required this.lastSender,
    required this.lastMessage,
    required this.timeAgo,
    required this.unread,
    required this.fromYou,
    required this.readByOthers,
    required this.isActive,
    required this.typing,
    required this.muted,
    required this.pinned,
  });

  _ChatGroup copyWith({
    int? unread,
    bool? muted,
    bool? pinned,
  }) =>
      _ChatGroup(
        id: id,
        name: name,
        members: members,
        lastSender: lastSender,
        lastMessage: lastMessage,
        timeAgo: timeAgo,
        unread: unread ?? this.unread,
        fromYou: fromYou,
        readByOthers: readByOthers,
        isActive: isActive,
        typing: typing,
        muted: muted ?? this.muted,
        pinned: pinned ?? this.pinned,
      );
}

class _DrivermessagesState extends State<Drivermessages> {
  _ChatFilter _filter = _ChatFilter.all;
  String _query = "";
  late TextEditingController _searchController;
  late List<_ChatGroup> _chats;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _chats = const [
      _ChatGroup(
        id: "g1",
        name: "Hostel City Trip",
        members: [
          _ChatMember(initial: "S", color: Color(0xffF472B6)),
          _ChatMember(initial: "A", color: Color(0xff60A5FA)),
          _ChatMember(initial: "H", color: Color(0xffFBBF24)),
        ],
        lastSender: "Sarah",
        lastMessage: "I'm at the gate, can you see me?",
        timeAgo: "2m",
        unread: 3,
        fromYou: false,
        readByOthers: false,
        isActive: true,
        typing: true,
        muted: false,
        pinned: true,
      ),
      _ChatGroup(
        id: "g2",
        name: "Faizabad Carpool",
        members: [
          _ChatMember(initial: "M", color: Color(0xff34D399)),
          _ChatMember(initial: "N", color: Color(0xffA78BFA)),
        ],
        lastSender: "You",
        lastMessage: "On my way, ETA 4 min",
        timeAgo: "1h",
        unread: 0,
        fromYou: true,
        readByOthers: true,
        isActive: false,
        typing: false,
        muted: false,
        pinned: false,
      ),
      _ChatGroup(
        id: "g3",
        name: "Bahria Phase 7",
        members: [
          _ChatMember(initial: "H", color: Color(0xffFBBF24)),
          _ChatMember(initial: "Z", color: Color(0xffEF4444)),
          _ChatMember(initial: "K", color: Color(0xff60A5FA)),
        ],
        lastSender: "Hina",
        lastMessage: "Thanks for the ride 🙏",
        timeAgo: "Yesterday",
        unread: 0,
        fromYou: false,
        readByOthers: false,
        isActive: false,
        typing: false,
        muted: true,
        pinned: false,
      ),
      _ChatGroup(
        id: "g4",
        name: "F-10 Markaz Ride",
        members: [
          _ChatMember(initial: "M", color: Color(0xffEC4899)),
          _ChatMember(initial: "I", color: Color(0xff34D399)),
        ],
        lastSender: "Mariam",
        lastMessage: "Could you wait 2 more minutes please?",
        timeAgo: "Yesterday",
        unread: 1,
        fromYou: false,
        readByOthers: false,
        isActive: false,
        typing: false,
        muted: false,
        pinned: false,
      ),
      _ChatGroup(
        id: "g5",
        name: "Saddar Pickup Group",
        members: [
          _ChatMember(initial: "T", color: Color(0xffA78BFA)),
          _ChatMember(initial: "B", color: Color(0xff60A5FA)),
        ],
        lastSender: "You",
        lastMessage: "Reached destination, ride completed",
        timeAgo: "2 days ago",
        unread: 0,
        fromYou: true,
        readByOthers: false,
        isActive: false,
        typing: false,
        muted: false,
        pinned: false,
      ),
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── State mutations ─────────────────────────────────────

  void _togglePin(String id) {
    setState(() {
      _chats = _chats
          .map((c) => c.id == id ? c.copyWith(pinned: !c.pinned) : c)
          .toList();
    });
  }

  void _toggleMute(String id) {
    setState(() {
      _chats = _chats
          .map((c) => c.id == id ? c.copyWith(muted: !c.muted) : c)
          .toList();
    });
  }

  void _markAsUnread(String id) {
    setState(() {
      _chats = _chats
          .map((c) =>
              c.id == id ? c.copyWith(unread: c.unread > 0 ? 0 : 1) : c)
          .toList();
    });
  }

  void _archive(_ChatGroup chat) {
    final originalIndex = _chats.indexWhere((c) => c.id == chat.id);
    if (originalIndex < 0) return;

    setState(() {
      _chats = List.of(_chats)..removeAt(originalIndex);
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
              Icon(Icons.archive_outlined,
                  size: 16.sp, color: Consonants.whiteColor),
              SizedBox(width: 8.w),
              Expanded(
                child: CustomWidgets.customText(
                  "Conversation archived",
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
                _chats = List.of(_chats)..insert(originalIndex, chat);
              });
            },
          ),
        ),
      );
  }

  Future<void> _onRefresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    // Bump the most-recent chat's unread count to simulate a new message.
    setState(() {
      if (_chats.isNotEmpty) {
        _chats = List.of(_chats);
        _chats[0] = _chats[0].copyWith(unread: _chats[0].unread + 1);
      }
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        CustomWidgets.customSuccessSnackBar("Messages updated"),
      );
  }

  void _openChat(_ChatGroup chat) {
    // Mark all messages as read on open.
    if (chat.unread > 0) {
      setState(() {
        _chats = _chats
            .map((c) => c.id == chat.id ? c.copyWith(unread: 0) : c)
            .toList();
      });
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DriverChatDetail(
          groupName: chat.name,
          isActive: chat.isActive,
          members: chat.members
              .map((m) => ChatMember(initial: m.initial, color: m.color))
              .toList(),
        ),
      ),
    );
  }

  // ─── Long-press action sheet ─────────────────────────────

  void _showActionSheet(_ChatGroup chat) {
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
                    children: [
                      _StackedAvatars(members: chat.members, size: 36.w),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomWidgets.customText(
                              chat.name,
                              13.sp,
                              Consonants.boldTextColor,
                              FontWeight.w800,
                            ),
                            SizedBox(height: 2.h),
                            CustomWidgets.customText(
                              "${chat.members.length + 1} members",
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
                  icon: chat.pinned
                      ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                  label: chat.pinned ? "Unpin chat" : "Pin chat",
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _togglePin(chat.id);
                  },
                ),
                _sheetAction(
                  icon: chat.muted
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                  label: chat.muted ? "Unmute" : "Mute notifications",
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _toggleMute(chat.id);
                  },
                ),
                _sheetAction(
                  icon: chat.unread > 0
                      ? Icons.mark_chat_read_outlined
                      : Icons.mark_chat_unread_outlined,
                  label: chat.unread > 0
                      ? "Mark as read"
                      : "Mark as unread",
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _markAsUnread(chat.id);
                  },
                ),
                _sheetAction(
                  icon: Icons.archive_outlined,
                  label: "Archive",
                  destructive: true,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _archive(chat);
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
    final filtered = _applyAll(_chats);
    final pinned = filtered.where((c) => c.pinned).toList();
    final recent = filtered.where((c) => !c.pinned).toList();

    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            SizedBox(height: 12.h),
            _searchBar(),
            SizedBox(height: 12.h),
            _filterPills(),
            SizedBox(height: 8.h),
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
                        padding: EdgeInsets.only(bottom: 24.h, top: 6.h),
                        children: [
                          if (pinned.isNotEmpty) ...[
                            _sectionLabel("Pinned"),
                            SizedBox(height: 8.h),
                            for (int i = 0; i < pinned.length; i++) ...[
                              _chatRow(pinned[i]),
                              if (i != pinned.length - 1)
                                _rowDivider(),
                            ],
                            SizedBox(height: 18.h),
                          ],
                          if (recent.isNotEmpty) ...[
                            _sectionLabel(
                              pinned.isEmpty ? "Conversations" : "Recent",
                            ),
                            SizedBox(height: 8.h),
                            for (int i = 0; i < recent.length; i++) ...[
                              _chatRow(recent[i]),
                              if (i != recent.length - 1) _rowDivider(),
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

  // Combines search + filter pill + pinned ordering.
  List<_ChatGroup> _applyAll(List<_ChatGroup> all) {
    var list = all;
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((c) {
        return c.name.toLowerCase().contains(q) ||
            c.lastMessage.toLowerCase().contains(q) ||
            c.lastSender.toLowerCase().contains(q);
      }).toList();
    }
    switch (_filter) {
      case _ChatFilter.all:
        break;
      case _ChatFilter.unread:
        list = list.where((c) => c.unread > 0).toList();
        break;
      case _ChatFilter.active:
        list = list.where((c) => c.isActive).toList();
        break;
    }
    return list;
  }

  // ─── Top bar ─────────────────────────────────────────────

  Widget _topBar() {
    final activeCount = _chats.where((c) => c.isActive).length;
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
              child: Icon(Icons.arrow_back_rounded,
                  size: 18.sp, color: Consonants.boldTextColor),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomWidgets.customText(
                  "Messages",
                  18.sp,
                  Consonants.boldTextColor,
                  FontWeight.w800,
                ),
                SizedBox(height: 2.h),
                CustomWidgets.customText(
                  activeCount > 0
                      ? "$activeCount active conversation${activeCount == 1 ? '' : 's'}"
                      : "${_chats.length} group chats",
                  10.sp,
                  Consonants.greyColor,
                  FontWeight.w500,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  CustomWidgets.customSuccessSnackBar(
                    "New group coming soon",
                  ),
                );
            },
            child: Container(
              width: 40.w,
              height: 40.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Consonants.primaryColor, Color(0xff5AC8FA)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Consonants.primaryColor.withValues(alpha: 0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(Icons.edit_rounded,
                  size: 16.sp, color: Consonants.whiteColor),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Search bar ─────────────────────────────────────────

  Widget _searchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Container(
        height: 44.h,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        decoration: BoxDecoration(
          color: Consonants.whiteColor,
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded,
                size: 18.sp, color: Consonants.greyColor),
            SizedBox(width: 8.w),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                cursorColor: Consonants.primaryColor,
                style: TextStyle(
                  fontFamily: Consonants.fontFamily,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Consonants.boldTextColor,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintText: "Search messages or groups…",
                  hintStyle: TextStyle(
                    fontFamily: Consonants.fontFamily,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: Consonants.greyColor,
                  ),
                ),
              ),
            ),
            if (_query.isNotEmpty)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _query = "";
                    _searchController.clear();
                  });
                },
                child: Icon(Icons.close_rounded,
                    size: 16.sp, color: Consonants.greyColor),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Filter pills ────────────────────────────────────────

  Widget _filterPills() {
    final unreadCount = _chats.where((c) => c.unread > 0).length;
    final activeCount = _chats.where((c) => c.isActive).length;
    return SizedBox(
      height: 36.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        children: [
          _pill("All", _ChatFilter.all, count: _chats.length),
          SizedBox(width: 8.w),
          _pill("Unread", _ChatFilter.unread, count: unreadCount),
          SizedBox(width: 8.w),
          _pill("Active", _ChatFilter.active, count: activeCount),
        ],
      ),
    );
  }

  Widget _pill(String label, _ChatFilter value, {int count = 0}) {
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
      padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 0),
      child: Row(
        children: [
          if (text == "Pinned") ...[
            Icon(Icons.push_pin_rounded,
                size: 11.sp, color: Consonants.greyColor),
            SizedBox(width: 4.w),
          ],
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

  Widget _rowDivider() {
    return Padding(
      padding: EdgeInsets.only(left: 88.w, right: 20.w),
      child: Container(height: 1, color: Consonants.lightGreyColor),
    );
  }

  // ─── Chat row (with swipe + long-press) ─────────────────

  Widget _chatRow(_ChatGroup chat) {
    return Dismissible(
      key: ValueKey(chat.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: const Color(0xffEF4444).withValues(alpha: 0.10),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 24.w),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.archive_outlined,
                size: 18.sp, color: const Color(0xffEF4444)),
            SizedBox(width: 6.w),
            CustomWidgets.customText(
              "Archive",
              11.sp,
              const Color(0xffEF4444),
              FontWeight.w800,
            ),
          ],
        ),
      ),
      onDismissed: (_) => _archive(chat),
      child: Material(
        color: Consonants.whiteColor,
        child: InkWell(
          onTap: () => _openChat(chat),
          onLongPress: () => _showActionSheet(chat),
          splashColor: Consonants.primaryColor.withValues(alpha: 0.06),
          highlightColor: Consonants.primaryColor.withValues(alpha: 0.04),
          child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _StackedAvatars(members: chat.members, size: 50.w),
                    if (chat.isActive)
                      Positioned(
                        right: -2.w,
                        bottom: -2.h,
                        child: Container(
                          width: 14.w,
                          height: 14.w,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Consonants.primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Consonants.whiteColor,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.directions_car_rounded,
                            size: 7.sp,
                            color: Consonants.whiteColor,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              chat.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: Consonants.fontFamily,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w800,
                                color: Consonants.boldTextColor,
                              ),
                            ),
                          ),
                          if (chat.pinned) ...[
                            SizedBox(width: 4.w),
                            Icon(Icons.push_pin_rounded,
                                size: 11.sp,
                                color: Consonants.greyColor),
                          ],
                          if (chat.muted) ...[
                            SizedBox(width: 4.w),
                            Icon(Icons.notifications_off_rounded,
                                size: 11.sp,
                                color: Consonants.greyColor),
                          ],
                          if (chat.isActive) ...[
                            SizedBox(width: 6.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 5.w, vertical: 1.5.h),
                              decoration: BoxDecoration(
                                color: Consonants.lightBlueColor,
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 4.w,
                                    height: 4.w,
                                    decoration: const BoxDecoration(
                                      color: Consonants.primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 3.w),
                                  CustomWidgets.customText(
                                    "Live",
                                    8.sp,
                                    Consonants.primaryColor,
                                    FontWeight.w800,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 3.h),
                      _lastMessageRow(chat),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    CustomWidgets.customText(
                      chat.timeAgo,
                      9.sp,
                      chat.unread > 0
                          ? Consonants.primaryColor
                          : Consonants.greyColor,
                      chat.unread > 0
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                    SizedBox(height: 6.h),
                    if (chat.unread > 0)
                      Container(
                        constraints:
                            BoxConstraints(minWidth: 18.w, minHeight: 18.w),
                        padding: EdgeInsets.symmetric(
                            horizontal: 5.w, vertical: 1.h),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Consonants.primaryColor,
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: CustomWidgets.customText(
                          chat.unread > 99 ? "99+" : "${chat.unread}",
                          9.sp,
                          Consonants.whiteColor,
                          FontWeight.w800,
                        ),
                      )
                    else if (chat.fromYou)
                      Icon(
                        chat.readByOthers
                            ? Icons.done_all_rounded
                            : Icons.done_rounded,
                        size: 14.sp,
                        color: chat.readByOthers
                            ? Consonants.primaryColor
                            : Consonants.greyColor,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _lastMessageRow(_ChatGroup chat) {
    if (chat.typing) {
      return Row(
        children: [
          CustomWidgets.customText(
            "${chat.lastSender} is typing",
            11.sp,
            Consonants.primaryColor,
            FontWeight.w700,
          ),
          SizedBox(width: 4.w),
          _typingDot(0),
          SizedBox(width: 2.w),
          _typingDot(1),
          SizedBox(width: 2.w),
          _typingDot(2),
        ],
      );
    }

    final senderLabel = chat.fromYou ? "You" : chat.lastSender;
    return Row(
      children: [
        Flexible(
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: TextStyle(
                fontFamily: Consonants.fontFamily,
                fontSize: 11.sp,
                fontWeight: FontWeight.w500,
                color: Consonants.greyColor,
                height: 1.4,
              ),
              children: [
                TextSpan(
                  text: "$senderLabel: ",
                  style: TextStyle(
                    fontWeight: chat.unread > 0
                        ? FontWeight.w800
                        : FontWeight.w700,
                    color: chat.unread > 0
                        ? Consonants.boldTextColor
                        : Consonants.greyColor,
                  ),
                ),
                TextSpan(
                  text: chat.lastMessage,
                  style: TextStyle(
                    fontWeight: chat.unread > 0
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: chat.unread > 0
                        ? Consonants.boldTextColor
                        : Consonants.greyColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 4.w),
        if (chat.members.isNotEmpty)
          CustomWidgets.customText(
            "· ${chat.members.length + 1}",
            10.sp,
            Consonants.greyColor,
            FontWeight.w500,
          ),
      ],
    );
  }

  Widget _typingDot(int phase) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 600 + (phase * 100)),
      curve: Curves.easeInOut,
      builder: (_, value, __) {
        return Container(
          width: 4.w,
          height: 4.w,
          decoration: BoxDecoration(
            color: Consonants.primaryColor.withValues(alpha: value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  // ─── Empty state ────────────────────────────────────────

  Widget _emptyState() {
    final (title, subtitle) = _emptyCopy();
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
                  Icons.forum_outlined,
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
    if (_query.isNotEmpty) {
      return (
        "No matches",
        "Nothing matched \"$_query\". Try another search.",
      );
    }
    switch (_filter) {
      case _ChatFilter.unread:
        return (
          "All caught up",
          "No unread group messages right now",
        );
      case _ChatFilter.active:
        return (
          "No active rides",
          "Group chats from your active rides will appear here",
        );
      case _ChatFilter.all:
        return (
          "No conversations yet",
          "Group chats with your passengers show up here",
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stacked group avatar — Instagram-style overlapping circles. Up to 3
// member initials are stacked; the rest is summarized as "+N".
// ─────────────────────────────────────────────────────────────────────────────

class _StackedAvatars extends StatelessWidget {
  final List<_ChatMember> members;
  final double size;

  const _StackedAvatars({required this.members, required this.size});

  @override
  Widget build(BuildContext context) {
    final shown = members.take(3).toList();
    final extra = members.length - shown.length;
    final small = size * 0.62;
    final overlap = small * 0.45;
    // Total width = small + (n-1) * (small - overlap)
    final visualCount =
        shown.length + (extra > 0 ? 1 : 0); // +1 for "+N" bubble
    final totalWidth = small + (visualCount - 1) * (small - overlap);

    return SizedBox(
      width: totalWidth,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < shown.length; i++)
            Positioned(
              left: i * (small - overlap),
              top: (size - small) / 2,
              child: _avatarBubble(
                child: Text(
                  shown[i].initial,
                  style: TextStyle(
                    color: Consonants.whiteColor,
                    fontFamily: Consonants.fontFamily,
                    fontSize: small * 0.42,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                bg: shown[i].color,
                diameter: small,
              ),
            ),
          if (extra > 0)
            Positioned(
              left: shown.length * (small - overlap),
              top: (size - small) / 2,
              child: _avatarBubble(
                child: CustomWidgets.customText(
                  "+$extra",
                  small * 0.34,
                  Consonants.boldTextColor,
                  FontWeight.w800,
                ),
                bg: Consonants.lightBlueColor,
                diameter: small,
              ),
            ),
        ],
      ),
    );
  }

  Widget _avatarBubble({
    required Widget child,
    required Color bg,
    required double diameter,
  }) {
    return Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: Consonants.whiteColor, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: bg.withValues(alpha: 0.30),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
