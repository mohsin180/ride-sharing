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
import 'package:ride_sharing/widgets/custom/appComponents.dart';

/// Passenger group-chat list. Mirrors [Drivermessages] in look and
/// behaviour but the seed senders read "Driver" instead of named
/// passengers — the user is the passenger, so the other party in
/// every shared-ride conversation is the driver.
///
/// UX behaviors:
///   • Search        — live-filters by group name and last message.
///   • Tap chat      — opens the chat-detail screen (currently shared
///                     with the driver flow).
///   • Long-press    — bottom-sheet menu: mark read/unread.
///   • Pull to refresh — refetches chats.
class Passengermessages extends ConsumerStatefulWidget {
  const Passengermessages({super.key});

  @override
  ConsumerState<Passengermessages> createState() => _PassengermessagesState();
}

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

class _PassengermessagesState extends ConsumerState<Passengermessages> {
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
    // Steps along the indigo→violet ramp, not a rainbow. Avatars still
    // separate members at a glance, but every hue stays inside the brand —
    // the system allows no third accent. Matches the palette the driver's
    // message list and chat detail use, so a member keeps one colour across
    // both screens.
    const palette = [
      Color(0xff6E4BC9),
      Color(0xff8A5BE0),
      Color(0xff4B3AA0),
      Color(0xffA044FF),
      Color(0xff5B3BB8),
      Color(0xff7C4DD6),
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
        .then((_) => _load());
  }

  // ─── Long-press action sheet ─────────────────────────────

  void _showActionSheet(_ChatGroup chat) {
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
                SheetHeader(title: chat.name),
                SizedBox(height: 14.h),
                Row(
                  children: [
                    _StackedAvatars(members: chat.members, size: 38.w),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Text(
                        "${chat.members.length + 1} members",
                        style: AppText.caption().copyWith(fontSize: 13.sp),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                const AppDivider(),
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
    final filtered = _applySearch(_chats);

    return Scaffold(
      backgroundColor: Consonants.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _topBar(),
            _searchBar(),
            SizedBox(height: 16.h),
            SizedBox(height: 12.h),
            Expanded(
              child: RefreshIndicator(
                color: Consonants.indigo,
                backgroundColor: Consonants.surface,
                onRefresh: _onRefresh,
                child: _loading && _chats.isEmpty
                    ? _statusList(const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Consonants.indigo,
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
                        padding: EdgeInsets.fromLTRB(
                          Consonants.gutter.w,
                          8.h,
                          Consonants.gutter.w,
                          32.h,
                        ),
                        children: [
                          const AppSectionHeading(label: "Conversations"),
                          for (int i = 0; i < filtered.length; i++) ...[
                            _chatRow(filtered[i]),
                            if (i != filtered.length - 1) const AppDivider(),
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

  /// Live search over group name, last message and last sender.
  List<_ChatGroup> _applySearch(List<_ChatGroup> all) {
    var list = all;
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((c) {
        return c.name.toLowerCase().contains(q) ||
            c.lastMessage.toLowerCase().contains(q) ||
            c.lastSender.toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }

  // ─── Top bar ─────────────────────────────────────────────

  Widget _topBar() {
    return AppHeader(
      title: "Messages",
      subtitle: "${_chats.length} group chats",
      showBack: true,
      onBack: () => context.pop(),
    );
  }

  // ─── Search bar ─────────────────────────────────────────

  Widget _searchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Consonants.surface,
          borderRadius: BorderRadius.circular(Consonants.rInput.r),
          border: Border.all(color: Consonants.border, width: 1.2),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: 20.sp,
              color: Consonants.iconInk,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                cursorColor: Consonants.violet,
                style: AppText.rowLabel().copyWith(fontSize: 15.5.sp),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintText: "Search messages or groups…",
                  hintStyle: AppText.rowLabel(color: Consonants.textMuted)
                      .copyWith(fontSize: 15.5.sp),
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
                child: Icon(
                  Icons.close_rounded,
                  size: 18.sp,
                  color: Consonants.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Chat row (with long-press) ─────────────────────────

  /// A conversation is a list row — divided by a 1px rule, no card.
  Widget _chatRow(_ChatGroup chat) {
    final unread = chat.unread > 0;
    return GestureDetector(
      onTap: () => _openChat(chat),
      onLongPress: () => _showActionSheet(chat),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: Consonants.rowVertical.h),
        child: Row(
          children: [
            _StackedAvatars(members: chat.members, size: 48.w),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.rowLabel(color: Consonants.headingInk)
                        .copyWith(
                      fontSize: 16.sp,
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  _lastMessageRow(chat),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  chat.timeAgo,
                  style: AppText.caption(
                    color: unread ? Consonants.indigo : Consonants.textMuted,
                  ).copyWith(fontSize: 12.sp),
                ),
                if (unread) ...[
                  SizedBox(height: 8.h),
                  Container(
                    constraints:
                        BoxConstraints(minWidth: 20.w, minHeight: 20.w),
                    padding:
                        EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Consonants.indigo,
                      borderRadius:
                          BorderRadius.circular(Consonants.rPill.r),
                    ),
                    child: Text(
                      chat.unread > 99 ? "99+" : "${chat.unread}",
                      style: AppText.navLabel(color: Consonants.surface)
                          .copyWith(fontSize: 11.sp),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _lastMessageRow(_ChatGroup chat) {
    final senderLabel = chat.lastSender;
    final unread = chat.unread > 0;
    return Row(
      children: [
        Flexible(
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: AppText.caption().copyWith(fontSize: 13.sp, height: 1.35),
              children: [
                if (senderLabel.isNotEmpty)
                  TextSpan(
                    text: "$senderLabel: ",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: unread
                          ? Consonants.bodyInk
                          : Consonants.textMuted,
                    ),
                  ),
                TextSpan(
                  text: chat.lastMessage,
                  style: TextStyle(
                    fontWeight:
                        unread ? FontWeight.w600 : FontWeight.w400,
                    color:
                        unread ? Consonants.bodyInk : Consonants.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 6.w),
        if (chat.members.isNotEmpty)
          Text(
            "· ${chat.members.length + 1}",
            style: AppText.caption().copyWith(fontSize: 12.sp),
          ),
      ],
    );
  }

  // ─── Empty state ────────────────────────────────────────

  Widget _emptyState() {
    final title = _query.isNotEmpty
        ? "No matches for \"$_query\""
        : "No conversations yet";
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
                  Icons.forum_outlined,
                  size: 34.sp,
                  color: Consonants.indigo,
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                title,
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
                  style: AppText.amount(color: Consonants.surface)
                      .copyWith(fontSize: small * 0.42),
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
                child: Text(
                  "+$extra",
                  style: AppText.amount(color: Consonants.indigo)
                      .copyWith(fontSize: small * 0.34),
                ),
                bg: Consonants.indigoWash,
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
        border: Border.all(color: Consonants.surface, width: 2.5),
      ),
      child: child,
    );
  }
}
