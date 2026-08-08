import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ride_sharing/controller/chatSocket.dart';
import 'package:ride_sharing/model/messagingModels.dart';
import 'package:ride_sharing/provider/messagingProvider.dart';
import 'package:ride_sharing/provider/providers.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';
import 'package:ride_sharing/widgets/consonants/errorHandler.dart';
import 'package:ride_sharing/widgets/consonants/jwtUtils.dart';
import 'package:ride_sharing/widgets/consonants/tokenStorage.dart';
import 'package:ride_sharing/widgets/custom/appComponents.dart';
import 'package:ride_sharing/widgets/custom/customWidgets.dart';

/// Group-chat detail screen (driver + passengers in a shared ride).
///
/// UX behaviours:
///   • Auto-scrolls to newest on open and on send.
///   • Composer expands up to 5 lines, send button activates only when text
///     is non-empty (mic icon shown otherwise as a hint for future voice).
///   • Long-press a bubble to copy its text to the clipboard.
///   • Date separators ("Today", "Yesterday") group messages by day so the
///     thread stays readable when it grows.
///   • Active rides surface a coloured banner at the top with a pulsing dot.

class ChatMember {
  final String initial;
  final Color color;
  const ChatMember({required this.initial, required this.color});
}

class DriverChatDetail extends ConsumerStatefulWidget {
  final String rideId;
  final String title;
  final List<ChatMember> members;
  final bool isActive;

  const DriverChatDetail({
    super.key,
    required this.rideId,
    required this.title,
    this.members = const [],
    this.isActive = false,
  });

  @override
  ConsumerState<DriverChatDetail> createState() => _DriverChatDetailState();
}

enum _Status { sending, sent, delivered, read }

class _Message {
  final String id;
  final String senderName;
  final String? senderInitial;
  final Color? senderColor;
  final String text;
  final DateTime time;
  final bool isMe;
  final _Status status;

  const _Message({
    required this.id,
    required this.senderName,
    this.senderInitial,
    this.senderColor,
    required this.text,
    required this.time,
    required this.isMe,
    this.status = _Status.read,
  });

  _Message copyWith({_Status? status}) => _Message(
        id: id,
        senderName: senderName,
        senderInitial: senderInitial,
        senderColor: senderColor,
        text: text,
        time: time,
        isMe: isMe,
        status: status ?? this.status,
      );
}

class _DriverChatDetailState extends ConsumerState<DriverChatDetail> {
  late final TextEditingController _composer;
  late final ScrollController _scroll;
  late final FocusNode _focus;
  final ChatSocket _socket = ChatSocket();
  Timer? _poll;

  List<_Message> _messages = [];
  String? _myUserId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _composer = TextEditingController();
    _scroll = ScrollController();
    _focus = FocusNode();
    _composer.addListener(() => setState(() {}));
    _init();
  }

  Future<void> _init() async {
    final token = await Tokenstorage.getToken();
    _myUserId = token != null ? JwtUtils.extractUserId(token) : null;
    try {
      final history =
          await ref.read(messagingServiceProvider).getMessages(widget.rideId);
      if (!mounted) return;
      setState(() {
        _messages = history.map(_fromServer).toList();
        _loading = false;
      });
      _scrollToBottomSoon();
      // Opening the chat clears its unread count.
      ref.invalidate(unreadMessagesCountProvider);
      ref.invalidate(myChatsProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ErrorHandler.message(e);
      });
    }
    // Live updates: the STOMP socket pushes new messages instantly. As a
    // fallback (e.g. if the WebSocket can't connect through the tunnel/proxy),
    // also poll the history every 4s and merge anything new — so messages
    // always appear within a few seconds even without the socket.
    await _socket.connect(rideId: widget.rideId, onMessage: _onIncoming);
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _pollMessages());
  }

  Future<void> _pollMessages() async {
    try {
      final latest =
          await ref.read(messagingServiceProvider).getMessages(widget.rideId);
      if (!mounted) return;
      final known = _messages.map((m) => m.id).toSet();
      final fresh =
          latest.where((m) => !known.contains(m.id)).map(_fromServer).toList();
      if (fresh.isEmpty) return;
      setState(() => _messages = [..._messages, ...fresh]);
      _scrollToBottomSoon();
      ref.read(messagingServiceProvider).markRead(widget.rideId);
      ref.invalidate(unreadMessagesCountProvider);
    } catch (_) {
      // Transient — the next tick retries.
    }
  }

  _Message _fromServer(ChatMessage m) {
    final mine = m.isMine(_myUserId);
    final name = m.senderName.trim();
    return _Message(
      id: m.id,
      senderName: mine ? "You" : (name.isEmpty ? "Member" : name),
      senderInitial: name.isNotEmpty ? name[0].toUpperCase() : "?",
      senderColor: _colorFor(m.senderId),
      text: m.text,
      time: (m.sentAt ?? DateTime.now()).toLocal(),
      isMe: mine,
    );
  }

  void _onIncoming(ChatMessage m) {
    if (!mounted) return;
    if (_messages.any((x) => x.id == m.id)) return; // dedupe our own echo
    setState(() => _messages = [..._messages, _fromServer(m)]);
    _scrollToBottomSoon();
    // A message arrived while we're viewing — keep read-state + badge fresh.
    ref.read(messagingServiceProvider).markRead(widget.rideId);
    ref.invalidate(unreadMessagesCountProvider);
  }

  Color _colorFor(String id) {
    // Sender colours stay inside the brand ramp — two hues, no rainbow.
    const palette = [
      Consonants.indigo,
      Consonants.violet,
      Consonants.indigoMid,
      Color(0xff6E4BC9),
      Color(0xff8A5BE0),
      Color(0xff4B3AA0),
    ];
    if (id.isEmpty) return palette[0];
    return palette[id.hashCode.abs() % palette.length];
  }

  @override
  void dispose() {
    _poll?.cancel();
    _socket.dispose();
    _composer.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ─── Sending ─────────────────────────────────────────────

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    _composer.clear();
    setState(() {});

    // Prefer the live socket — the server echoes the message back over the
    // ride topic, which appends it. If the socket is down, fall back to REST
    // and append the returned message directly.
    final overSocket = _socket.send(widget.rideId, text);
    if (overSocket) return;
    try {
      final msg =
          await ref.read(messagingServiceProvider).sendMessage(widget.rideId, text);
      if (!mounted) return;
      if (!_messages.any((x) => x.id == msg.id)) {
        setState(() => _messages = [..._messages, _fromServer(msg)]);
        _scrollToBottomSoon();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(CustomWidgets.customErrorSnackBar(ErrorHandler.message(e)));
    }
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(jump: true));
  }

  void _scrollToBottom({bool jump = false}) {
    if (!_scroll.hasClients) return;
    final target = _scroll.position.maxScrollExtent;
    if (jump) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  // ─── Long-press menu ─────────────────────────────────────

  void _showMessageActions(_Message msg) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Consonants.scrim,
      builder: (sheetCtx) {
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
                  child: const SheetHeader(title: "Message"),
                ),
                SizedBox(height: 10.h),
                _sheetAction(
                  icon: Icons.reply_rounded,
                  label: "Reply",
                  onTap: () => Navigator.pop(sheetCtx),
                ),
                _sheetAction(
                  icon: Icons.copy_rounded,
                  label: "Copy text",
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Clipboard.setData(ClipboardData(text: msg.text));
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        CustomWidgets.customSuccessSnackBar("Copied"),
                      );
                  },
                ),
                _sheetAction(
                  icon: Icons.emoji_emotions_outlined,
                  label: "React",
                  onTap: () => Navigator.pop(sheetCtx),
                ),
                if (msg.isMe)
                  _sheetAction(
                    icon: Icons.delete_outline_rounded,
                    label: "Delete",
                    destructive: true,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      setState(() {
                        _messages =
                            _messages.where((m) => m.id != msg.id).toList();
                      });
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
    return Scaffold(
      backgroundColor: Consonants.canvas,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            if (widget.isActive) _activeRideBanner(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Consonants.indigo,
                        strokeWidth: 2.5,
                      ),
                    )
                  : _error != null
                      ? _errorView(_error!)
                      : _messageList(),
            ),
            _composerBar(),
          ],
        ),
      ),
    );
  }

  // ─── Top bar ─────────────────────────────────────────────

  Widget _topBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          Consonants.gutter.w, 14.h, Consonants.gutter.w, 14.h),
      decoration: const BoxDecoration(
        color: Consonants.canvas,
        border: Border(bottom: BorderSide(color: Consonants.divider)),
      ),
      child: Row(
        children: [
          AppIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
          SizedBox(width: 14.w),
          _StackedAvatars(members: widget.members, size: 42.w),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.sectionHeading().copyWith(fontSize: 17.sp),
                ),
                SizedBox(height: 3.h),
                Text(
                  "${widget.members.length + 1} members",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption().copyWith(fontSize: 12.5.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Active ride banner ──────────────────────────────────

  Widget _activeRideBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: Consonants.gutter.w, vertical: 10.h),
      color: Consonants.indigoWash,
      child: Row(
        children: [
          const _PulseDot(color: Consonants.violet),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              "Live ride · driver in transit",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.navLabel(color: Consonants.indigo)
                  .copyWith(fontSize: 13.sp),
            ),
          ),
        ],
      ),
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
          ],
        ),
      ),
    );
  }

  // ─── Message list ────────────────────────────────────────

  Widget _messageList() {
    final items = _buildItems();
    return ListView.builder(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is _DateHeader) return _dateSeparator(item.label);
        final msg = item as _Message;
        final showSender = _shouldShowSenderHeader(items, index);
        return _bubble(msg, showSender: showSender);
      },
    );
  }

  // Inserts date-separator headers between messages from different days.
  List<Object> _buildItems() {
    final items = <Object>[];
    DateTime? lastDay;
    for (final m in _messages) {
      final day = DateTime(m.time.year, m.time.month, m.time.day);
      if (lastDay == null || day != lastDay) {
        items.add(_DateHeader(_dayLabel(day)));
        lastDay = day;
      }
      items.add(m);
    }
    return items;
  }

  bool _shouldShowSenderHeader(List<Object> items, int index) {
    final msg = items[index] as _Message;
    if (msg.isMe) return false;
    if (index == 0) return true;
    final prev = items[index - 1];
    if (prev is _DateHeader) return true;
    if (prev is _Message && prev.senderName == msg.senderName) return false;
    return true;
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (d == today) return "Today";
    if (d == yesterday) return "Yesterday";
    return "${d.day}/${d.month}/${d.year}";
  }

  Widget _dateSeparator(String label) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: Consonants.chipBg,
            borderRadius: BorderRadius.circular(Consonants.rPill.r),
          ),
          child: Text(
            label,
            style: AppText.navLabel(color: Consonants.iconInk)
                .copyWith(fontSize: 12.sp),
          ),
        ),
      ),
    );
  }

  // ─── Bubble ──────────────────────────────────────────────

  Widget _bubble(_Message msg, {required bool showSender}) {
    final isMe = msg.isMe;
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            _miniAvatar(msg, visible: showSender),
            SizedBox(width: 6.w),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe && showSender) ...[
                  Padding(
                    padding: EdgeInsets.only(left: 6.w, bottom: 4.h),
                    child: Text(
                      msg.senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.navLabel(
                        color: msg.senderColor ?? Consonants.textMuted,
                      ).copyWith(fontSize: 12.sp),
                    ),
                  ),
                ],
                GestureDetector(
                  onLongPress: () => _showMessageActions(msg),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 268.w),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 16.w, vertical: 12.h),
                      decoration: BoxDecoration(
                        color:
                            isMe ? Consonants.indigo : Consonants.surface,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(isMe ? 18.r : 6.r),
                          topRight: Radius.circular(isMe ? 6.r : 18.r),
                          bottomLeft: Radius.circular(18.r),
                          bottomRight: Radius.circular(18.r),
                        ),
                        boxShadow: isMe ? null : Consonants.cardLift,
                      ),
                      child: Text(
                        msg.text,
                        style: AppText.paragraph(
                          color: isMe
                              ? Consonants.surface
                              : Consonants.bodyInk,
                        ).copyWith(fontSize: 15.sp),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 5.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.w),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(msg.time),
                        style: AppText.caption().copyWith(fontSize: 11.5.sp),
                      ),
                      if (isMe) ...[
                        SizedBox(width: 5.w),
                        _statusIcon(msg.status),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniAvatar(_Message msg, {required bool visible}) {
    if (!visible) {
      return SizedBox(width: 28.w);
    }
    final color = msg.senderColor ?? Consonants.indigo;
    return Container(
      width: 28.w,
      height: 28.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Consonants.canvas, width: 2),
      ),
      child: Text(
        msg.senderInitial ?? msg.senderName.substring(0, 1),
        style: AppText.navLabel(color: Consonants.surface)
            .copyWith(fontSize: 11.sp),
      ),
    );
  }

  Widget _statusIcon(_Status status) {
    switch (status) {
      case _Status.sending:
        return Icon(Icons.access_time_rounded,
            size: 12.sp, color: Consonants.textMuted);
      case _Status.sent:
        return Icon(Icons.done_rounded,
            size: 12.sp, color: Consonants.textMuted);
      case _Status.delivered:
        return Icon(Icons.done_all_rounded,
            size: 12.sp, color: Consonants.textMuted);
      case _Status.read:
        return Icon(Icons.done_all_rounded,
            size: 12.sp, color: Consonants.violet);
    }
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }

  // ─── Composer ────────────────────────────────────────────

  Widget _composerBar() {
    final canSend = _composer.text.trim().isNotEmpty;
    return Container(
      decoration: const BoxDecoration(
        color: Consonants.canvas,
        border: Border(top: BorderSide(color: Consonants.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              Consonants.gutter.w, 12.h, Consonants.gutter.w, 12.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: BoxConstraints(
                    minHeight: 48.h,
                    maxHeight: 128.h,
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  decoration: BoxDecoration(
                    color: Consonants.surface,
                    borderRadius:
                        BorderRadius.circular(Consonants.rInput.r),
                    border: Border.all(
                        color: Consonants.border, width: 1.2),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _composer,
                          focusNode: _focus,
                          maxLines: 5,
                          minLines: 1,
                          textInputAction: TextInputAction.newline,
                          cursorColor: Consonants.violet,
                          style: AppText.rowLabel().copyWith(
                            fontSize: 15.5.sp,
                            height: 1.4,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            isCollapsed: true,
                            contentPadding:
                                EdgeInsets.symmetric(vertical: 14.h),
                            hintText: "Message…",
                            hintStyle: AppText.rowLabel(
                              color: Consonants.textMuted,
                            ).copyWith(fontSize: 15.5.sp),
                          ),
                        ),
                      ),
                      Icon(Icons.emoji_emotions_outlined,
                          size: 20.sp, color: Consonants.iconInk),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              GestureDetector(
                onTap: canSend ? _send : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 48.w,
                  height: 48.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: canSend ? Consonants.actionGradient : null,
                    color: canSend ? null : Consonants.chipBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    canSend ? Icons.send_rounded : Icons.mic_none_rounded,
                    size: 20.sp,
                    color: canSend
                        ? Consonants.surface
                        : Consonants.iconInk,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stacked group avatar (compact — used in the chat header).
// ─────────────────────────────────────────────────────────────────────────────

class _StackedAvatars extends StatelessWidget {
  final List<ChatMember> members;
  final double size;
  const _StackedAvatars({required this.members, required this.size});

  @override
  Widget build(BuildContext context) {
    final shown = members.take(3).toList();
    final extra = members.length - shown.length;
    final small = size * 0.62;
    final overlap = small * 0.45;
    final visualCount = shown.length + (extra > 0 ? 1 : 0);
    final totalWidth =
        small + (visualCount > 0 ? (visualCount - 1) * (small - overlap) : 0);

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
              child: _avatar(
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
              child: _avatar(
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

  Widget _avatar({
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
        border: Border.all(color: Consonants.canvas, width: 2),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated pulse dot (active-ride banner).
// ─────────────────────────────────────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 8.w,
        height: 8.w,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.5 + 0.5 * _ctrl.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _DateHeader {
  final String label;
  const _DateHeader(this.label);
}
