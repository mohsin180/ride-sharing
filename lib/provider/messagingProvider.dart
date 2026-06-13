import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ride_sharing/model/messagingModels.dart';
import 'package:ride_sharing/provider/providers.dart';

/// The user's chats (one per ride), newest activity first. Backed by
/// `GET /api/v1/messages/chats`. Invalidate after sending / on refresh.
final myChatsProvider = FutureProvider<List<ChatConversation>>((ref) {
  return ref.read(messagingServiceProvider).getMyChats();
});

/// Total unread message count for the home messages-bell badge. Backed by
/// `GET /api/v1/messages/unread-count`.
final unreadMessagesCountProvider = FutureProvider<int>((ref) {
  return ref.read(messagingServiceProvider).getUnreadCount();
});
