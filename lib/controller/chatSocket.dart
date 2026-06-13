import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:ride_sharing/model/messagingModels.dart';
import 'package:ride_sharing/widgets/consonants/apiConsonants.dart';
import 'package:ride_sharing/widgets/consonants/tokenStorage.dart';

/// STOMP-over-WebSocket client for one ride's chat. Connects to
/// messaging-service through the gateway (the gateway authenticates the
/// upgrade and injects `X-User-Id`), subscribes to `/topic/chat.<rideId>`,
/// and sends to `/app/chat/<rideId>`. One instance per open conversation;
/// call [dispose] when the chat screen closes.
class ChatSocket {
  StompClient? _client;
  bool _connected = false;

  bool get isConnected => _connected;

  Future<void> connect({
    required String rideId,
    required void Function(ChatMessage) onMessage,
    void Function()? onReady,
  }) async {
    final token = await Tokenstorage.getToken();
    final headers = <String, String>{
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    _client = StompClient(
      config: StompConfig(
        url: Apiconsonants.chatWsUrl,
        // Sent on the HTTP upgrade so the gateway can validate + inject
        // X-User-Id, and again on the STOMP CONNECT frame for good measure.
        webSocketConnectHeaders: headers,
        stompConnectHeaders: headers,
        onConnect: (frame) {
          _connected = true;
          _client?.subscribe(
            destination: '/topic/chat.$rideId',
            callback: (f) {
              final body = f.body;
              if (body == null || body.isEmpty) return;
              try {
                final decoded = jsonDecode(body);
                if (decoded is Map<String, dynamic>) {
                  onMessage(ChatMessage.fromJson(decoded));
                }
              } catch (_) {
                // Ignore malformed frames.
              }
            },
          );
          onReady?.call();
        },
        onWebSocketError: (_) => _connected = false,
        onDisconnect: (_) => _connected = false,
        onStompError: (_) {},
      ),
    );
    _client!.activate();
  }

  /// Sends a text message over the socket. Returns false if not connected
  /// (caller should fall back to the REST send).
  bool send(String rideId, String text) {
    final client = _client;
    if (client == null || !_connected) return false;
    client.send(
      destination: '/app/chat/$rideId',
      body: jsonEncode({'text': text}),
    );
    return true;
  }

  void dispose() {
    _connected = false;
    _client?.deactivate();
    _client = null;
  }
}
