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

/// Driver group-chat list. Every conversation is a shared-ride group
/// (driver + passengers), never 1:1.
///
/// UX behaviors:
///   • Search        — live-filters by group name and last message.
///   • Tap chat      — opens the chat-detail screen.
///   • Long-press    — bottom-sheet menu: mark read/unread.
///   • Pull to refresh — refetches chats.
class Drivermessages extends ConsumerStatefulWidget {
  const Drivermessages({super.key});

  @override
  ConsumerState<Drivermessages> createState() => _DrivermessagesState();
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

class _DrivermessagesState extends ConsumerState<Drivermessages> {
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
    // Avatar fills stay inside the brand ramp — the app has exactly two hues,
    // so a rainbow of member colours would read as a different product.
    const palette = [
      Consonants.indigo,
      Consonants.violet,
      Consonants.indigoMid,
      Color(0xff6E4BC9),
      Color(0xff8A5BE0),
      Color(0xff4B3AA0),
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
                  child: SheetHeader(title: chat.name),
                ),
                SizedBox(height: 16.h),
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
                  child: Row(
                    children: [
                      _StackedAvatars(members: chat.members, size: 40.w),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Text(
                          "${chat.members.length + 1} members",
                          style:
                              AppText.caption().copyWith(fontSize: 12.5.sp),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 18.h),
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
            SizedBox(height: 14.h),
            Expanded(
              child: RefreshIndicator(
                color: Consonants.indigo,
                backgroundColor: Consonants.surface,
                onRefresh: _onRefresh,
                child: _loading && _chats.isEmpty
                    ? _statusList(const Center(
                        child: CircularProgressIndicator(
                          color: Consonants.indigo,
                          strokeWidth: 2.5,
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
                        padding: EdgeInsets.only(bottom: 32.h, top: 6.h),
                        children: [
                          _sectionLabel("Conversations"),
                          SizedBox(height: 4.h),
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
      showBack: true,
      onBack: () => context.pop(),
    );
  }

  // ─── Search bar ─────────────────────────────────────────

  Widget _searchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Consonants.gutter.w),
      child: AppInput(
        hint: "Search messages or groups…",
        controller: _searchController,
        leadingIcon: Icons.search_rounded,
        onChanged: (v) => setState(() => _query = v),
        trailing: _query.isEmpty
            ? null
            : GestureDetector(
                onTap: () {
                  setState(() {
                    _query = "";
                    _searchController.clear();
                  });
                },
                child: Icon(Icons.close_rounded,
                    size: 18.sp, color: Consonants.iconInk),
              ),
      ),
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

  Widget _rowDivider() {
    return Padding(
      padding: EdgeInsets.only(
          left: Consonants.gutter.w + 64.w, right: Consonants.gutter.w),
      child: const AppDivider(),
    );
  }

  // ─── Chat row (with swipe + long-press) ─────────────────

  Widget _chatRow(_ChatGroup chat) {
    final unread = chat.unread > 0;
    return Material(
      color: Consonants.canvas,
      child: InkWell(
        onTap: () => _openChat(chat),
        onLongPress: () => _showActionSheet(chat),
        splashColor: Consonants.violet.withValues(alpha: 0.06),
        highlightColor: Consonants.violet.withValues(alpha: 0.04),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Consonants.gutter.w,
            vertical: Consonants.rowVertical.h,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _StackedAvatars(members: chat.members, size: 50.w),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chat.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.rowLabel().copyWith(
                        fontSize: 16.sp,
                        fontWeight:
                            unread ? FontWeight.w700 : FontWeight.w500,
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
                      color: unread
                          ? Consonants.indigo
                          : Consonants.textMuted,
                    ).copyWith(fontSize: 12.sp),
                  ),
                  SizedBox(height: 8.h),
                  if (unread)
                    Container(
                      constraints:
                          BoxConstraints(minWidth: 20.w, minHeight: 20.w),
                      padding: EdgeInsets.symmetric(
                          horizontal: 6.w, vertical: 2.h),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: Consonants.actionGradient,
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lastMessageRow(_ChatGroup chat) {
    final senderLabel = chat.lastSender;
    final unread = chat.unread > 0;
    final base = AppText.caption().copyWith(fontSize: 13.5.sp, height: 1.35);
    return Row(
      children: [
        Flexible(
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: base,
              children: [
                if (senderLabel.isNotEmpty)
                  TextSpan(
                    text: "$senderLabel: ",
                    style: base.copyWith(
                      fontWeight: FontWeight.w600,
                      color: unread
                          ? Consonants.bodyInk
                          : Consonants.textMuted,
                    ),
                  ),
                TextSpan(
                  text: chat.lastMessage,
                  style: base.copyWith(
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
                  Icons.forum_outlined,
                  size: 34.sp,
                  color: Consonants.iconInk,
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
        border: Border.all(color: Consonants.canvas, width: 2.5),
      ),
      child: child,
    );
  }
}
