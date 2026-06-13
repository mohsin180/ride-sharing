import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:ride_sharing/model/trackingModels.dart';
import 'package:ride_sharing/widgets/consonants/apiConsonants.dart';
import 'package:ride_sharing/widgets/consonants/tokenStorage.dart';

/// STOMP client for one ride's live tracking. Same WebSocket endpoint as
/// the chat (messaging-service), different topic: subscribes to
/// `/topic/track.<rideId>` for everyone's positions and publishes its own
/// to `/app/track/<rideId>`. One instance per open trip screen.
class TrackingSocket {
  StompClient? _client;
  bool _connected = false;

  bool get isConnected => _connected;

  Future<void> connect({
    required String rideId,
    required void Function(TrackPosition) onPosition,
    void Function()? onReady,
  }) async {
    final token = await Tokenstorage.getToken();
    final headers = <String, String>{
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    _client = StompClient(
      config: StompConfig(
        url: Apiconsonants.trackWsUrl,
        webSocketConnectHeaders: headers,
        stompConnectHeaders: headers,
        onConnect: (frame) {
          _connected = true;
          _client?.subscribe(
            destination: '/topic/track.$rideId',
            callback: (f) {
              final body = f.body;
              if (body == null || body.isEmpty) return;
              try {
                final decoded = jsonDecode(body);
                if (decoded is Map<String, dynamic>) {
                  onPosition(TrackPosition.fromJson(decoded));
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

  /// Publishes the caller's current position. Returns false if not yet
  /// connected (the next GPS tick will retry).
  bool send(
    String rideId, {
    required double lat,
    required double lng,
    required String role,
    double? bearing,
  }) {
    final client = _client;
    if (client == null || !_connected) return false;
    client.send(
      destination: '/app/track/$rideId',
      body: jsonEncode({
        'lat': lat,
        'lng': lng,
        'role': role,
        if (bearing != null) 'bearing': bearing,
      }),
    );
    return true;
  }

  void dispose() {
    _connected = false;
    _client?.deactivate();
    _client = null;
  }
}
