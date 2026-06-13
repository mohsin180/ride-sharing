import 'package:ride_sharing/controller/apiClient.dart';
import 'package:ride_sharing/model/messagingModels.dart';
import 'package:ride_sharing/widgets/consonants/apiConsonants.dart';

/// REST surface for chat (the live channel is WebSocket — see ChatSocket).
/// The caller is identified server-side from the gateway-injected user, so
/// none of these take a userId.
class Messagingservice {
  final Apiclient apiclient;
  Messagingservice({required this.apiclient});

  /// The user's chats, one per ride, newest activity first.
  Future<List<ChatConversation>> getMyChats() async {
    final json = await apiclient.get(Apiconsonants.myChatsEndpoint);
    if (json is! List) return const [];
    return json
        .whereType<Map<String, dynamic>>()
        .map(ChatConversation.fromJson)
        .toList(growable: false);
  }

  /// Full message history for a ride's chat. Opening it marks it read.
  Future<List<ChatMessage>> getMessages(String rideId) async {
    final json = await apiclient.get(Apiconsonants.chatMessagesEndpoint(rideId));
    if (json is! List) return const [];
    return json
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList(growable: false);
  }

  /// REST fallback for sending when the socket is down. Returns the stored
  /// message (also broadcast to other members over WebSocket).
  Future<ChatMessage> sendMessage(String rideId, String text) async {
    final json = await apiclient.post(
      Apiconsonants.sendMessageEndpoint(rideId),
      {"text": text},
    );
    return ChatMessage.fromJson(json as Map<String, dynamic>);
  }

  Future<void> markRead(String rideId) async {
    await apiclient.post(Apiconsonants.markChatReadEndpoint(rideId), const {});
  }

  Future<int> getUnreadCount() async {
    final json = await apiclient.get(Apiconsonants.unreadMessagesCountEndpoint);
    if (json is Map && json['count'] is num) {
      return (json['count'] as num).toInt();
    }
    return 0;
  }
}
