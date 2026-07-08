/// Client-side notification type — drives the icon/colour on the cards.
/// Mirrors the `type` string sent by notification-service.
enum NotifType {
  request,
  driverOffer,
  trip,
  rating,
  system;

  static NotifType fromWire(String? raw) {
    switch (raw?.toUpperCase()) {
      case 'REQUEST':
        return NotifType.request;
      case 'DRIVER_OFFER':
        return NotifType.driverOffer;
      case 'TRIP':
        return NotifType.trip;
      case 'RATING':
        return NotifType.rating;
      case 'SYSTEM':
      default:
        return NotifType.system;
    }
  }
}

/// One in-app notification. Backed by `GET /api/v1/notifications`.
///
/// Backend contract (one object per item in the array):
///   {
///     "id":        "uuid",
///     "type":      "TRIP",                  // REQUEST | TRIP | RATING | SYSTEM
///     "title":     "Ride accepted",
///     "body":      "A driver accepted your ride to ...",
///     "rideId":    "uuid" | null,
///     "read":      false,
///     "createdAt": "2026-06-09T10:30:00Z"
///   }
class AppNotification {
  final String id;
  final NotifType type;
  final String title;
  final String body;
  final DateTime? createdAt;
  final bool read;
  final String? rideId;

  /// For an actionable RATING prompt: the co-passenger to rate (id + name).
  /// For a JOIN_REQUEST: the requester (id + name + rating + their route +
  /// the request id to accept/decline). Null for informational notifications.
  final String? subjectUserId;
  final String? subjectName;
  final double? subjectRating;
  final String? requestId;
  final String? pickup;
  final String? drop;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    this.createdAt,
    this.rideId,
    this.subjectUserId,
    this.subjectName,
    this.subjectRating,
    this.requestId,
    this.pickup,
    this.drop,
  });

  /// True when tapping this notification should open a rating sheet for a
  /// co-passenger (a leave-triggered rate prompt).
  bool get isRatePrompt =>
      type == NotifType.rating &&
      rideId != null &&
      subjectUserId != null &&
      subjectUserId!.isNotEmpty;

  /// True when this is a co-passenger's join request for the host to accept
  /// or decline. Type-scoped so a driver offer (which reuses [requestId])
  /// doesn't match.
  bool get isJoinRequest =>
      type == NotifType.request &&
      rideId != null &&
      requestId != null &&
      requestId!.isNotEmpty &&
      subjectUserId != null;

  /// True when this is a driver's offer for the host to accept or decline.
  /// [requestId] carries the offer id; [subjectUserId]/[subjectName]/
  /// [subjectRating] are the driver's.
  bool get isDriverOffer =>
      type == NotifType.driverOffer &&
      rideId != null &&
      requestId != null &&
      requestId!.isNotEmpty &&
      subjectUserId != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    DateTime? readDate(String key) {
      final raw = json[key];
      if (raw is! String || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    double? readDouble(String key) {
      final v = json[key];
      return v is num ? v.toDouble() : null;
    }

    return AppNotification(
      id: (json['id'] ?? '').toString(),
      type: NotifType.fromWire(json['type'] as String?),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      createdAt: readDate('createdAt'),
      read: switch (json['read']) {
        bool b => b,
        _ => false,
      },
      rideId: json['rideId'] as String?,
      subjectUserId: json['subjectUserId'] as String?,
      subjectName: json['subjectName'] as String?,
      subjectRating: readDouble('subjectRating'),
      requestId: json['requestId'] as String?,
      pickup: json['pickup'] as String?,
      drop: json['drop'] as String?,
    );
  }

  /// True when this notification was created today (local time) — used to
  /// split the list into "Today" vs "Earlier".
  bool get isToday {
    final dt = createdAt;
    if (dt == null) return false;
    final now = DateTime.now();
    final local = dt.toLocal();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  /// "5 min ago" / "2 h ago" / "Yesterday" / "3 d ago" — locale-agnostic
  /// so we don't pull in `package:intl` for one label.
  String get relativeTime {
    final dt = createdAt;
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} d ago';
  }
}
