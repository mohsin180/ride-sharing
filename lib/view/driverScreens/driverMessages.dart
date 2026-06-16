import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:ride_sharing/model/messagingModels.dart';
import 'package:ride_sharing/provider/messagingProvider.dart';
import 'package:ride_sharing/provider/providers.dart';
import 'package:ride_sharing/view/driverScreens/driverChatDetail.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

/// Driver group-chat list. Every conversation is a shared-ride group
/// (driver + passengers), never 1:1.
///
/// UX behaviors:
///   • Search        — live-filters by group name and last message.
///   • Filter pills  — All / Unread, with live counts.
///   • Tap chat      — opens the chat-detail screen.
///   • Long-press    — bottom-sheet menu: mark read/unread.
///   • Pull to refresh — refetches chats.
class Drivermessages extends ConsumerStatefulWidget {
  const Drivermessages({super.key});

  @override
  ConsumerState<Drivermessages> createState() => _DrivermessagesState();
}

enum _ChatFilter { all, unread }

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

  const _ChatGroup({
    required this.id,
    required this.name,
    required this.members,
    required this.lastSender,
    required this.lastMessage,
    required this.timeAgo,
    required this.unread,
  });

  _ChatGroup copyWith({
    int? unread,
  }) =>
      _ChatGroup(
        id: id,
        name: name,
        members: members,
        lastSender: lastSender,
        lastMessage: lastMessage,
        timeAgo: timeAgo,
        unread: unread ?? this.unread,
      );
}

class _DrivermessagesState extends ConsumerState<Drivermessages> {
  _ChatFilter _filter = _ChatFilter.all;
  String _query = "";
  late TextEditingController _searchController;
  List<_ChatGroup> _chats = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final chats = await ref.read(messagingServiceProvider).getMyChats();
      if (!mounted) return;
      setState(() {
        _chats = chats.map(_fromConversation).toList();
        _loading = false;
      });
      ref.invalidate(unreadMessagesCountProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ErrorHandler.message(e);
      });
    }
  }

  _ChatGroup _fromConversation(ChatConversation c) {
    const palette = [
      Color(0xff60A5FA),
      Color(0xffF472B6),
      Color(0xffFBBF24),
      Color(0xff34D399),
      Color(0xffA78BFA),
      Color(0xffEC4899),
    ];
    final members = <_ChatMember>[];
    for (int i = 0; i < c.memberNames.length; i++) {
      final n = c.memberNames[i].trim();
      members.add(_ChatMember(
        initial: n.isNotEmpty ? n[0].toUpperCase() : "?",
        color: palette[i % palette.length],
      ));
    }
    return _ChatGroup(
      id: c.rideId,
      name: c.title,
      members: members,
      lastSender: c.lastSenderName ?? "",
      lastMessage: c.lastMessage ?? "No messages yet",
      timeAgo: _relativeTime(c.lastSentAt),
      unread: c.unread,
    );
  }

  String _relativeTime(DateTime? dt) {
    if (dt == null) return "";
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return "now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m";
    if (diff.inHours < 24) return "${diff.inHours}h";
    if (diff.inDays == 1) return "Yesterday";
    return "${diff.inDays}d ago";
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── State mutations ─────────────────────────────────────

  void _markAsUnread(String id) {
    setState(() {
      _chats = _chats
          .map((c) =>
              c.id == id ? c.copyWith(unread: c.unread > 0 ? 0 : 1) : c)
          .toList();
    });
  }

  Future<void> _onRefresh() async {
    await _load();
  }

  void _openChat(_ChatGroup chat) {
    // Optimistically clear the unread pip on open.
    if (chat.unread > 0) {
      setState(() {
        _chats = _chats
            .map((c) => c.id == chat.id ? c.copyWith(unread: 0) : c)
            .toList();
      });
    }
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => DriverChatDetail(
              rideId: chat.id,
              title: chat.name,
              members: chat.members
                  .map((m) => ChatMember(initial: m.initial, color: m.color))
                  .toList(),
            ),
          ),
        )
        .then((_) => _load()); // refresh list + unread on return
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
                child: _loading && _chats.isEmpty
                    ? _statusList(const Center(
                        child: CircularProgressIndicator(
                          color: Consonants.primaryColor,
                        ),
                      ))
                    : _error != null && _chats.isEmpty
                        ? _statusList(_errorView(_error!))
                        : filtered.isEmpty
                    ? _emptyState()
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: EdgeInsets.only(bottom: 24.h, top: 6.h),
                        children: [
                          _sectionLabel("Conversations"),
                          SizedBox(height: 8.h),
                          for (int i = 0; i < filtered.length; i++) ...[
                            _chatRow(filtered[i]),
                            if (i != filtered.length - 1) _rowDivider(),
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

  Widget _statusList(Widget child) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [SizedBox(height: 160.h), child],
    );
  }

  Widget _errorView(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 36.sp, color: Consonants.greyColor),
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

  // Combines search + filter pill.
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
    }
    return list;
  }

  // ─── Top bar ─────────────────────────────────────────────

  Widget _topBar() {
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
                  "${_chats.length} group chats",
                  10.sp,
                  Consonants.greyColor,
                  FontWeight.w500,
                ),
              ],
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
    return Material(
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
                _StackedAvatars(members: chat.members, size: 50.w),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
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
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
    );
  }

  Widget _lastMessageRow(_ChatGroup chat) {
    final senderLabel = chat.lastSender;
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
                if (senderLabel.isNotEmpty)
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
