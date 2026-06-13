/// One row in the chat-list screen — a ride's group chat. Backed by
/// `GET /api/v1/messages/chats`.
class ChatConversation {
  final String rideId;
  final String title;
  final List<String> memberNames;
  final String? lastMessage;
  final String? lastSenderName;
  final DateTime? lastSentAt;
  final int unread;

  const ChatConversation({
    required this.rideId,
    required this.title,
    required this.memberNames,
    required this.unread,
    this.lastMessage,
    this.lastSenderName,
    this.lastSentAt,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    DateTime? readDate(String key) {
      final raw = json[key];
      if (raw is! String || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    final rawMembers = json['memberNames'];
    final members = rawMembers is List
        ? rawMembers.map((e) => e.toString()).toList(growable: false)
        : const <String>[];

    return ChatConversation(
      rideId: (json['rideId'] ?? '').toString(),
      title: (json['title'] ?? 'Ride chat').toString(),
      memberNames: members,
      lastMessage: json['lastMessage'] as String?,
      lastSenderName: json['lastSenderName'] as String?,
      lastSentAt: readDate('lastSentAt'),
      unread: json['unreadCount'] is num
          ? (json['unreadCount'] as num).toInt()
          : 0,
    );
  }
}

/// A single chat message. Backed by `GET /api/v1/messages/{rideId}` and the
/// `/topic/chat.<rideId>` WebSocket broadcast (same JSON shape).
class ChatMessage {
  final String id;
  final String rideId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime? sentAt;

  const ChatMessage({
    required this.id,
    required this.rideId,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.sentAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    DateTime? readDate(String key) {
      final raw = json[key];
      if (raw is! String || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    return ChatMessage(
      id: (json['id'] ?? '').toString(),
      rideId: (json['rideId'] ?? '').toString(),
      senderId: (json['senderId'] ?? '').toString(),
      senderName: (json['senderName'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      sentAt: readDate('sentAt'),
    );
  }

  /// True when the authenticated user is the sender (right-aligned bubble).
  bool isMine(String? myUserId) => myUserId != null && senderId == myUserId;
}
